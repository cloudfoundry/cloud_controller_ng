#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CC_DIR="${DIR}/.."

echo "this no longer does anything, because of mutual TLS the worker has to run inside bosh-lite until we come up with a solution"
exit 1

pushd "${CC_DIR}" > /dev/null
  export CLOUD_CONTROLLER_NG_CONFIG="${CC_DIR}/config/bosh-lite.yml"
  export BUNDLE_GEMFILE="${CC_DIR}/Gemfile"

  bundle exec rake jobs:local[worker.0]
popd > /dev/null
