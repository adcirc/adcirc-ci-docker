# Build stage with Spack pre-installed and ready to be used
FROM spack/rockylinux9:develop AS builder


RUN dnf install -y procps wget
RUN wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/84c039b6-2b7d-4544-a745-3fcf8afd643f/intel-dpcpp-cpp-compiler-2025.0.4.20_offline.sh && \
    bash ./intel-dpcpp-cpp-compiler-2025.0.4.20_offline.sh -a -s --eula accept --install-dir /opt/intel && \
    rm intel-dpcpp-cpp-compiler-2025.0.4.20_offline.sh 
RUN wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/ad42ee3b-7a2f-41cb-b902-689f651920da/intel-fortran-compiler-2025.0.4.21_offline.sh && \
    bash ./intel-fortran-compiler-2025.0.4.21_offline.sh -a -s --eula accept --install-dir /opt/intel && \
    rm intel-fortran-compiler-2025.0.4.21_offline.sh 
RUN source /opt/intel/setvars.sh && spack compiler find 
RUN git clone https://github.com/adcirc/adcirc-spack && spack repo add adcirc-spack


# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir -p /opt/spack-environment && \
set -o noclobber \
&&  (echo spack: \
&&   echo '  specs:' \
&&   echo '  - netcdf-c ^hdf5~mpi %oneapi' \
&&   echo '  - netcdf-fortran fflags="-heap-arrays 8192" %oneapi' \
&&   echo '  - xdmf3+fortran fflags="-heap-arrays 8182" %oneapi' \
&&   echo '  - openmpi+legacylaunchers+internal-hwloc+internal-pmix+internal-libevent fabrics=none fflags="-heap-arrays 8192" %oneapi' \
&&   echo '  - cmake' \
&&   echo '  - ninja' \
&&   echo '  - libjpeg-turbo' \
&&   echo '  - python+optimizations@3.11.9' \
&&   echo '  - py-pip' \
&&   echo '  concretizer:' \
&&   echo '    unify: true' \
&&   echo '  config:' \
&&   echo '    template_dirs:' \
&&   echo '    - templates' \
&&   echo '    install_tree: /opt/software' \
&&   echo '  view: /opt/views/view') > /opt/spack-environment/spack.yaml

# Install the software, remove unnecessary deps
RUN cd /opt/spack-environment && spack env activate . && spack install --fail-fast && spack gc -y

# Strip all the binaries
RUN find -L /opt/views/view/* -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip

# Modifications to the environment that are necessary to run
RUN cd /opt/spack-environment && \
    spack env activate --sh -d . > activate.sh



# Bare OS image to run the installed executables
FROM docker.io/rockylinux:9

COPY --from=builder /opt/spack-environment /opt/spack-environment
COPY --from=builder /opt/software /opt/software

# paths.view is a symlink, so copy the parent to avoid dereferencing and duplicating it
COPY --from=builder /opt/views /opt/views

RUN { \
      echo '#!/bin/sh' \
      && echo '.' /opt/spack-environment/activate.sh \
      && echo 'exec "$@"'; \
    } > /entrypoint.sh \
&& chmod a+x /entrypoint.sh \
&& ln -s /opt/views/view /opt/view


RUN dnf update -y && dnf install -y epel-release && dnf update -y \
 && dnf install -y gcc gcc-c++ git git-lfs procps ncurses which make \
 && rm -rf /var/cache/dnf && dnf clean all


COPY --from=builder /opt/intel /opt/intel 
RUN /opt/view/bin/pip install basemap basemap-data-hires numpy matplotlib pyyaml xarray netCDF4 tqdm awscli boto3
RUN echo mpi=exclude >> /opt/intel/config.txt && \
    echo export SETVARS_ARGS=--config=/opt/intel/config.txt >> /opt/spack-environment/activate.sh && \
    echo "source /opt/intel/setvars.sh 2>&1 > /dev/null" >> /opt/spack-environment/activate.sh && \
    echo export NETCDFHOME=/opt/view >> /opt/spack-environment/activate.sh && \
    echo export NETCDF_FORTRAN_HOME=/opt/view >> /opt/spack-environment/activate.sh && \
    echo export HDF5HOME=/opt/view >> /opt/spack-environment/activate.sh && \
    echo export HDF5_ROOT=/opt/view >> /opt/spack-environment/activate.sh && \ 
    echo export XDMFHOME=/opt/view >> /opt/spack-environment/activate.sh
RUN useradd -m adcirc -u 1001
USER adcirc
WORKDIR /home/adcirc
LABEL "maintainer"="Zach Cobell <zcobell@gmail.com>"
LABEL "io.k8s.description"="ADCIRC CI Container"
LABEL "io.openshift.expose-services"="None"
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/bin/bash" ]

