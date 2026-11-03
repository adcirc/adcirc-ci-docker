# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom
#
# ADCIRC CI image: the devel base image plus the Python packages used by the
# CI jobs and the test suite that the base image does not already have (AWS
# access to test data), and map data for the test suite plots.
#
# The devel image to build on, e.g. adcircorg/adcirc-base:2026.1.0-devel-amd64.
# There is deliberately no default so that the CI image is always built on an
# explicit version (scripts/build.sh passes the one it just built).
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

SHELL [ "/bin/bash", "-o", "pipefail", "-c" ]

USER 0

# The packages are added to the base image's Python environment
# (/opt/python), which is already on PATH. The map data used by the test suite
# plots is downloaded once into a read-only location so that it is available
# to any user the image runs as.
COPY requirements.txt /opt/python/ci-requirements.txt
RUN /opt/python/bin/pip install --no-cache-dir --only-binary=:all: \
        -r /opt/python/requirements.txt -r /opt/python/ci-requirements.txt && \
    cartopy_feature_download --no-warn --output /opt/cartopy-data \
        gshhs physical cultural cultural-extra
ENV CARTOPY_DATA_DIR=/opt/cartopy-data

USER 1001
WORKDIR /home/adcirc

LABEL "org.opencontainers.image.title"="ADCIRC CI"
LABEL "org.opencontainers.image.description"="Environment used to build and test ADCIRC in continuous integration"
LABEL "org.opencontainers.image.variant"="ci"
