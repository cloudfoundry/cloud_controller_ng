#!/bin/bash
set -Eeuxo pipefail
set -o allexport
# shellcheck disable=SC2064
trap "pkill -P $$" EXIT

# Setup volume mounts
mkdir -p tmp

# Speed up docker builds by prebuilding with buildx
docker-compose pull || tee tmp/fail &
docker buildx bake -f docker-compose.yml -f .devcontainer/docker-compose.override.yml || tee tmp/fail &

wait $(jobs -p)
test -f tmp/fail && rm tmp/fail && exit 1

trap "" EXIT