# Build stage with Spack pre-installed and ready to be used
FROM spack/rockylinux9:develop AS builder


RUN mkdir -p /opt/spack-compiler-environment && \
set -o noclobber \
&&  (echo spack: \
&&   echo '  specs:' \
&&   echo '  - gcc+piclibs+strip@14.2.0' \
&&   echo '  concretizer:' \
&&   echo '    unify: true' \
&&   echo '  config:' \
&&   echo '    template_dirs:' \
&&   echo '    - templates' \
&&   echo '    install_tree: /opt/compilers' \
&&   echo '  view: /opt/views/compiler-view') > /opt/spack-compiler-environment/spack.yaml

# Install the software, remove unnecessary deps
RUN cd /opt/spack-compiler-environment && spack env activate . && spack install --fail-fast && spack gc -y
RUN spack compilers && spack compiler add /opt/compilers/linux-*/gcc-*/gcc-14.* && spack compilers

RUN git clone https://github.com/adcirc/adcirc-spack && spack repo add adcirc-spack


# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir -p /opt/spack-environment && \
set -o noclobber \
&&  (echo spack: \
&&   echo '  specs:' \
&&   echo '  - netcdf-c ^hdf5~mpi %gcc@14.2.0' \
&&   echo '  - netcdf-fortran %gcc@14.2.0' \
&&   echo '  - xdmf3+fortran %gcc@14.2.0' \
&&   echo '  - openmpi+legacylaunchers+internal-hwloc+internal-pmix+internal-libevent fabrics=none %gcc@14.2.0' \
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
 && dnf install -y gcc which ncurses git git-lfs make \
 && rm -rf /var/cache/dnf && dnf clean all


COPY --from=builder /opt/compilers /opt/compilers
RUN /opt/view/bin/pip install numpy matplotlib pyyaml xarray netCDF4 tqdm awscli boto3
RUN echo export NETCDFHOME=/opt/view >> /opt/spack-environment/activate.sh && \
    echo export NETCDF_FORTRAN_HOME=/opt/view >> /opt/spack-environment/activate.sh && \
    echo export HDF5HOME=/opt/view >> /opt/spack-environment/activate.sh && \
    echo export HDF5_ROOT=/opt/view >> /opt/spack-environment/activate.sh && \ 
    echo export XDMFHOME=/opt/view >> /opt/spack-environment/activate.sh && \
    echo export PATH=\$PATH:/opt/views/compiler-view/bin >> /opt/spack-environment/activate.sh && \
    echo export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/views/compiler-view/lib >> /opt/spack-environment/activate.sh && \ 
    echo export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/views/compiler-view/lib64 >> /opt/spack-environment/activate.sh && \
    echo export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/views/view/lib64 >> /opt/spack-environment/activate.sh
RUN useradd -m adcirc -u 1001
USER adcirc
WORKDIR /home/adcirc
LABEL "maintainer"="Zach Cobell <zcobell@gmail.com>"
LABEL "io.k8s.description"="ADCIRC CI Container"
LABEL "io.openshift.expose-services"="None"
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/bin/bash" ]

