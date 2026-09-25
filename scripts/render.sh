#!/usr/bin/env bash
#
# Render base/Dockerfile from base/spack.yaml with `spack containerize`.
#
# Spack runs inside the same pinned image used as the build stage so the
# output does not depend on the Spack version installed locally.
#
# Usage: scripts/render.sh [--check]
#   --check  fail if base/Dockerfile is out of date instead of rewriting it
#
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base="${root}/base"
image="$(awk '$1 == "build:" {print $2; exit}' "${base}/spack.yaml")"

rendered="$(mktemp)"
trap 'rm -f "${rendered}"' EXIT

# The environment must be active for its config (template_dirs) to apply, and
# activating it writes metadata next to spack.yaml. The inputs are streamed
# into the container rather than mounted so that nothing the container writes
# (as root) ends up on the host.
tar -C "${base}" -cf - spack.yaml templates | \
  docker run --rm -i --entrypoint /bin/sh "${image}" -c \
    'mkdir /tmp/env && tar --warning=no-unknown-keyword -C /tmp/env -xf - && cd /tmp/env && /opt/spack/bin/spack -e . containerize' \
  > "${rendered}"

if [[ "${1:-}" == "--check" ]]; then
  if ! diff -u "${base}/Dockerfile" "${rendered}"; then
    echo "base/Dockerfile is out of date; run scripts/render.sh" >&2
    exit 1
  fi
else
  cp "${rendered}" "${base}/Dockerfile"
fi
