# syntax=docker/dockerfile:1
#
# ADCIRC CI image: the devel base image plus the Python packages used by the
# CI jobs and the test suite (plotting, AWS access to test data).
#
ARG BASE_IMAGE=adcircorg/adcirc-base:latest-devel
FROM ${BASE_IMAGE}

SHELL [ "/bin/bash", "-o", "pipefail", "-c" ]

USER 0

# hadolint ignore=DL3033
RUN yum install -y python3.14 python3.14-pip && \
    rm -rf /var/cache/yum && \
    yum clean all

COPY requirements.txt /opt/ci-python/requirements.txt
RUN python3.14 -m venv /opt/ci-python && \
    /opt/ci-python/bin/pip install --no-cache-dir --only-binary=:all: \
        -r /opt/ci-python/requirements.txt

# activate.sh sets PATH outright, so the virtual environment is added there
# for jobs that source it as well as through ENV for everything else
RUN echo "export PATH=/opt/ci-python/bin:\$PATH" >> /opt/spack-environment/activate.sh
ENV PATH=/opt/ci-python/bin:${PATH}

# Map data used by the test suite plots, downloaded once into a read-only
# location so that it is available to any user the image runs as
RUN cartopy_feature_download --no-warn --output /opt/cartopy-data \
        gshhs physical cultural cultural-extra
ENV CARTOPY_DATA_DIR=/opt/cartopy-data

USER 1001
WORKDIR /home/adcirc

LABEL "org.opencontainers.image.title"="ADCIRC CI"
LABEL "org.opencontainers.image.description"="Environment used to build and test ADCIRC in continuous integration"
LABEL "org.opencontainers.image.variant"="ci"
