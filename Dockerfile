# Dockerfile to create the ADCIRC testing environment
# 
# Written By: Zach Cobell
# Contact: zcobell@thewaterinstitute.org
#
# This Dockerfile create an environment with the base
# software installed that is needed to test the ADCIRC
# model. The container installs:
#  - Generic base software (i.e. git, wget, cmake, etc)
#  - Intel OneAPI compilers and MPI libraries
#  - netCDF c/fortran (+hdf5)
#  - XDMF
#
# Once the software is installed, an environment file is
# written to /etc/environment for use by CircleCI
FROM spack/ubuntu-jammy:latest

#...Install software from package managers including the Intel compilers
RUN apt-get update --fix-missing && apt-get --yes install ca-certificates wget gpg cmake git git-lfs libboost-dev libxml2-dev libjpeg-dev && \
    wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list && \
    apt-get update; apt-get install --yes intel-oneapi-compiler-fortran intel-oneapi-compiler-dpcpp-cpp && \
    rm -rf /var/lib/apt/lists/*

#...Install software from spack
RUN source /opt/intel/oneapi/setvars.sh && \
    spack compiler find && \
    spack external find --all --not-buildable && \
    spack install netcdf-fortran ^hdf5~mpi %oneapi && \
    spack install libxml2 %oneapi && \
    spack install openmpi +internal-hwloc~vt %oneapi

#...Install xdmf
# Note that we need to patch xdmf because it is stale and conflicts typedefs with hdf5 > 1.10.x
RUN source /opt/intel/oneapi/setvars.sh && \
    export HDF5_HOME=$(spack find -p --no-groups hdf5 %oneapi | tr -s ' ' | cut -d$' ' -f2) && \
    git clone https://gitlab.kitware.com/xdmf/xdmf.git && cd xdmf && \
    perl -w -pi -e "s/typedef\ int\ hid\_t\;/typedef\ int64\_t\ hid\_t\;/g" core/XdmfHDF5Controller.hpp core/XdmfHDF5Writer.hpp && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icx -DCMAKE_Fortran_COMPILER=ifx -DCMAKE_INSTALL_PREFIX=/opt/xdmf \
             -DXDMF_BUILD_UTILS=ON -DXDMF_BUILD_FORTRAN=ON -DHDF5_ROOT=$HDF5_HOME -DBUILD_SHARED_LIBS=ON && \
    make -j4 && make install && cd ../.. && rm -rf xdmf

#...Add a non-root user
RUN useradd -ms /bin/bash adcirc

#...Create an environment file
# This file is sourced by the ci environment
# If running manually, be sure to run:
#
# source /etc/environment
#
RUN echo export NETCDFHOME=$(spack find -p --no-groups netcdf-c | tr -s ' ' | cut -d$' ' -f2) >>  /home/adcirc/.bashrc && \
    echo export HDF5HOME=$(spack find -p --no-groups hdf5 | tr -s ' ' | cut -d$' ' -f2) >> /home/adcirc/.bashrc && \
    echo export HDF5_ROOT=$(spack find -p --no-groups hdf5 | tr -s ' ' | cut -d$' ' -f2) >> /home/adcirc/.bashrc && \
    echo export NETCDF_FORTRAN_HOME=$(spack find -p --no-groups netcdf-fortran | tr -s ' ' | cut -d$' ' -f2) >> /home/adcirc/.bashrc && \
    echo export XDMFHOME=/opt/xdmf >> /home/adcirc/.bashrc && \
    echo export PATH=$(spack find -p --no-groups netcdf-c | tr -s ' ' | cut -d$' ' -f2)/bin:\
$(spack find -p --no-groups netcdf-fortran | tr -s ' ' | cut -d$' ' -f2)/bin:\
$(spack find -p --no-groups openmpi | tr -s ' ' | cut -d$' ' -f2)/bin:\
/opt/intel/oneapi/compiler/latest/linux/bin/intel64:\
/opt/intel/oneapi/compiler/latest/linux/bin:$PATH >> /home/adcirc/.bashrc  && \
    echo export LD_LIBRARY_PATH=$(spack find -p --no-groups netcdf-c | tr -s ' ' | cut -d$' ' -f2)/lib:\
$(spack find -p --no-groups netcdf-fortran | tr -s ' ' | cut -d$' ' -f2)/lib:\
$(spack find -p --no-groups openmpi | tr -s ' ' | cut -d$' ' -f2)/lib:\
/opt/intel/oneapi/compiler/latest/linux/compiler/lib/intel64_lin >> /home/adcirc/.bashrc
RUN chown adcirc:adcirc /home/adcirc/.bashrc

USER adcirc
WORKDIR /home/adcirc
ENV ENV=/home/adcirc/.bashrc