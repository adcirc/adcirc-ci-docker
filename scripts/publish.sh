#!/usr/bin/env bash
#
# Combine the per-architecture images pushed by scripts/build.sh into
# multi-arch tags:
#
#   adcircorg/adcirc-base:<version>-devel     (+ latest-devel)
#   adcircorg/adcirc-base:<version>-runtime   (+ latest-runtime)
#   adcircorg/adcirc-ci:<version>             (+ latest)
#
# Usage: scripts/publish.sh <version> [--latest]
#
set -euo pipefail

version="${1:-}"
if [[ -z "${version}" ]]; then
  echo "Usage: $0 <version> [--latest]" >&2
  exit 2
fi
latest=false
[[ "${2:-}" == "--latest" ]] && latest=true

publish() {
  local image="$1" tag="$2" latest_tag="$3"
  local tags=(-t "${image}:${tag}")
  if [[ "${latest}" == true ]]; then
    tags+=(-t "${image}:${latest_tag}")
  fi
  docker buildx imagetools create "${tags[@]}" \
    "${image}:${tag}-amd64" "${image}:${tag}-arm64"
  docker buildx imagetools inspect "${image}:${tag}"
}

publish adcircorg/adcirc-base "${version}-devel" latest-devel
publish adcircorg/adcirc-base "${version}-runtime" latest-runtime
publish adcircorg/adcirc-ci "${version}" latest
