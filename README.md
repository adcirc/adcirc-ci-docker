# ADCIRC Base and CI Containers

This repository builds the container images that ADCIRC is built, tested, and distributed with. All of them come from
one Spack environment, so the published model image, the CI image, and the development image share the same compilers
and libraries.

| Image | Contents | Used by |
|---|---|---|
| `adcircorg/adcirc-base:<version>-devel` | Compilers, libraries, and build tools | Building ADCIRC; users compiling their own code |
| `adcircorg/adcirc-base:<version>-runtime` | Libraries and compiler runtime libraries, no compilers | The published `adcircorg/adcirc` image |
| `adcircorg/adcirc-ci:<version>` | `devel` plus the Python packages used by CI and the test suite | CircleCI |

Every image is published for `linux/amd64` and `linux/arm64`:

| Architecture | Compilers | CPU target |
|---|---|---|
| `linux/amd64` | Intel oneAPI (`icx`, `icpx`, `ifx`) | `x86_64_v3` (Haswell and newer) |
| `linux/arm64` | GCC | `aarch64` |

The libraries in the Spack environment are netCDF-C and netCDF-Fortran (with HDF5), XDMF3, OpenMPI, and libjpeg-turbo,
plus CMake and Ninja. The `adcirc` package repository comes from
[adcirc-spack](https://github.com/adcirc/adcirc-spack).

## Layout

| Path | Purpose |
|---|---|
| `base/spack.yaml` | The Spack environment and container settings for both architectures |
| `base/templates/container/Dockerfile.adcirc` | Template used by `spack containerize` (devel and runtime targets) |
| `base/Dockerfile` | Rendered from the two files above; do not edit by hand |
| `ci/` | The CI image, built on top of `devel`, and its pinned Python requirements |
| `scripts/render.sh` | Renders `base/Dockerfile` |
| `scripts/smoke-test.sh` | Tests run against the images after they are built |
| `scripts/build.sh` | Builds, tests, and pushes the images for the current architecture |
| `scripts/publish.sh` | Combines the per-architecture images into multi-arch tags |

## Changing the environment

1. Edit `base/spack.yaml` or the template.
2. Run `scripts/render.sh` to regenerate `base/Dockerfile`. It runs `spack containerize` inside the pinned Spack
   build image, so the result does not depend on a local Spack installation. Pull requests fail if
   `base/Dockerfile` is out of date.
3. Commit all three files.

The CPU target is fixed in `base/spack.yaml` so that images do not depend on the CPU of the machine that built them.

## Building and publishing

The images are built by hand rather than in CI, because a cold build compiles every package (and, on arm64, GCC
itself), which takes several hours. Each architecture must be built on a machine of that architecture: oneAPI is only
available for x86_64, and building the stack under emulation is far too slow.

1. On an amd64 machine and on an arm64 machine, build, test, and push that architecture's images:

   ```bash
   scripts/build.sh 2026.1.0 --push
   ```

   This builds the `devel`, `runtime`, and CI images, runs `scripts/smoke-test.sh` against them (including as
   arbitrary UIDs), and pushes them as per-architecture tags such as `adcircorg/adcirc-base:2026.1.0-devel-arm64`.
   Without `--push` the images are only built and tested locally.

2. From either machine, combine the two architectures into multi-arch tags:

   ```bash
   scripts/publish.sh 2026.1.0 --latest
   ```

   This publishes `adcircorg/adcirc-base:2026.1.0-devel`, `adcircorg/adcirc-base:2026.1.0-runtime`, and
   `adcircorg/adcirc-ci:2026.1.0`, and with `--latest` also moves the `latest-devel`, `latest-runtime`, and `latest`
   tags.

Both steps need `docker login` for Docker Hub.

### Spack build cache

Set `SPACK_BUILDCACHE` to reuse packages that were already built, so that a rebuild only compiles what changed:

```bash
export SPACK_BUILDCACHE=oci://ghcr.io/adcirc/spack-buildcache
export SPACK_BUILDCACHE_USER=<github user>
export SPACK_BUILDCACHE_TOKEN=<token with write:packages>
scripts/build.sh 2026.1.0 --push
```

With only `SPACK_BUILDCACHE` set, packages are read from the cache (the package must be public). With the user and
token as well, packages built during the run are pushed to it. The Intel compilers are not redistributable and are
never pushed; Spack downloads them from Intel on each build.

## Updating the CI Python packages

`ci/requirements.txt` is a lock file generated from `ci/requirements.in` on the same OS and Python version the CI
image uses:

```bash
docker run --rm -v "$PWD/ci:/ci" rockylinux/rockylinux:9.8 bash -c '
  dnf install -y -q python3.14 python3.14-pip &&
  python3.14 -m venv /v && /v/bin/pip install -q --only-binary=:all: -r /ci/requirements.in &&
  /v/bin/pip freeze'
```

Replace the package lines in `ci/requirements.txt` with the output, and check that the result is the same for
`--platform linux/amd64` and `--platform linux/arm64`.
