# Dockerfile to create the ADCIRC testing environment
# 
# Written By: Zach Cobell
# Contact: zcobell@thewaterinstitute.org
#
# This Dockerfile create an environment with the base
# software installed that is needed to test the ADCIRC
# model. The container installs:
#  - Generic base software (i.e. git, wget, cmake, etc)
#  - netCDF c/fortran (+hdf5)
#  - openmpi
#  - git, git-lfs
FROM rockylinux:9.3-minimal
RUN microdnf update -y && \
    microdnf install -y yum && \
    yum update && yum install -y epel-release && \
    yum install -y cmake gcc gcc-c++ gcc-fortran make netcdf-devel netcdf-fortran-devel openssh git git-lfs openmpi-devel python3-devel && \
    yum clean all && rm -rf /var/cache/yum && \
    pip install pyyaml matplotlib basemap basemap-data-hires pyproj numpy xarray netCDF4 tqdm 

RUN echo export PATH=$PATH:/usr/lib64/openmpi/bin >> /etc/environment
