#!/usr/bin/env bash
#
# Build and test the devel, runtime, and CI images for one architecture, and
# optionally push them as per-architecture tags:
#
#   adcircorg/adcirc-base:<version>-devel-<arch>
#   adcircorg/adcirc-base:<version>-runtime-<arch>
#   adcircorg/adcirc-ci:<version>-<arch>
#
# Run once for amd64 and once for arm64, then combine the results into
# multi-arch tags with scripts/publish.sh. The architecture defaults to the
# Docker host's. Building the other architecture runs under QEMU emulation,
# which must be registered with the Docker host (see the message printed when
# it is not) and is much slower than a native build.
#
# Usage: scripts/build.sh <version> [--arch amd64|arm64] [--push]
#
# Environment:
#   SPACK_BUILDCACHE        optional Spack OCI build cache to pull packages
#                           from, e.g. oci://ghcr.io/adcirc/spack-buildcache
#   SPACK_BUILDCACHE_USER   with SPACK_BUILDCACHE_TOKEN, also push newly
#   SPACK_BUILDCACHE_TOKEN  built packages to the build cache
#
set -euo pipefail

usage() {
  echo "Usage: $0 <version> [--arch amd64|arm64] [--push]" >&2
  exit 2
}

version="${1:-}"
[[ -n "${version}" && "${version}" != -* ]] || usage
shift

host_arch="$(docker version --format '{{.Server.Arch}}')"
arch="${host_arch}"
push=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      [[ $# -ge 2 ]] || usage
      arch="$2"
      shift 2
      ;;
    --push)
      push=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done

case "${arch}" in
  amd64 | arm64) ;;
  *)
    echo "Unsupported architecture: ${arch}" >&2
    exit 1
    ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_image="adcircorg/adcirc-base"
ci_image="adcircorg/adcirc-ci"
platform="linux/${arch}"

if [[ "${arch}" != "${host_arch}" ]]; then
  final_image="$(awk '$1 == "final:" {print $2; exit}' "${root}/base/spack.yaml")"
  echo "==> Building ${arch} on a ${host_arch} host under emulation"
  if ! docker run --rm --platform "${platform}" "${final_image}" true > /dev/null 2>&1; then
    cat >&2 << EOF
This Docker host cannot run ${platform} containers. Register QEMU emulation
once per host (requires a privileged container), then run this script again:

  docker run --privileged --rm tonistiigi/binfmt --install ${arch}
EOF
    exit 1
  fi
fi

devel="${base_image}:${version}-devel-${arch}"
runtime="${base_image}:${version}-runtime-${arch}"
ci="${ci_image}:${version}-${arch}"

"${root}/scripts/render.sh" --check

build_args=(--platform "${platform}" --load --provenance=false)
if [[ -n "${SPACK_BUILDCACHE:-}" ]]; then
  build_args+=(--build-arg "SPACK_BUILDCACHE=${SPACK_BUILDCACHE}")
  if [[ -n "${SPACK_BUILDCACHE_TOKEN:-}" ]]; then
    build_args+=(--secret "id=buildcache_user,env=SPACK_BUILDCACHE_USER"
                 --secret "id=buildcache_token,env=SPACK_BUILDCACHE_TOKEN")
  fi
fi

echo "==> Building ${devel}"
docker buildx build "${build_args[@]}" --target devel -t "${devel}" "${root}/base"
echo "==> Building ${runtime}"
docker buildx build "${build_args[@]}" --target runtime -t "${runtime}" "${root}/base"
# The CI image is built FROM the devel image that was just loaded into the
# local image store. Builders using the docker-container driver cannot see
# that store and would look for the image in the registry, so use the Docker
# context's own builder (docker driver), which is named after the context.
echo "==> Building ${ci}"
docker buildx build --builder "$(docker context show)" \
  --platform "${platform}" --load --provenance=false \
  --build-arg "BASE_IMAGE=${devel}" -t "${ci}" "${root}/ci"

# Programs are built with the devel image and run in the runtime image, as
# the ADCIRC image does. The entrypoint is bypassed so that only the image ENV
# is used. --platform makes Docker run the images under emulation when they
# are not for the host's architecture.
echo "==> Testing"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
chmod 777 "${work}"
run() {
  docker run --rm --platform "${platform}" --entrypoint /bin/bash \
    -v "${root}/scripts:/scripts:ro" -v "${work}:/work" "$@"
}
run "${devel}" /scripts/smoke-test.sh devel /work
run "${runtime}" /scripts/smoke-test.sh runtime /work
run "${ci}" /scripts/smoke-test.sh ci

# Platforms such as OpenShift, and `docker run --user`, use a UID that does
# not exist in the image
run --user 54321:0 "${runtime}" /scripts/smoke-test.sh runtime /work
run --user 54321:54321 "${runtime}" /scripts/smoke-test.sh runtime /work
run --user 54321:54321 "${ci}" /scripts/smoke-test.sh ci
# Through the entrypoint, such a user gets a writable HOME
for image in "${runtime}" "${ci}"; do
  docker run --rm --platform "${platform}" --user 54321:54321 "${image}" \
    bash -c 'touch "${HOME}/.write-test" && echo "HOME=${HOME} is writable"'
  docker run --rm --platform "${platform}" --user 54321:0 "${image}" \
    bash -c 'test "${HOME}" = /home/adcirc && touch "${HOME}/.write-test"'
done

docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | \
  grep -F -e "${version}-devel-${arch}" -e "${version}-runtime-${arch}" -e "${ci_image}:${version}-${arch}"

if [[ "${push}" == true ]]; then
  for image in "${devel}" "${runtime}" "${ci}"; do
    echo "==> Pushing ${image}"
    docker push "${image}"
  done
  echo "Pushed ${arch} images. Run scripts/publish.sh ${version} once both architectures are pushed."
fi
