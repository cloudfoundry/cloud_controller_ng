#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CC_DIR="${DIR}/.."

pushd "${CC_DIR}" > /dev/null
  export CLOUD_CONTROLLER_NG_CONFIG="${CC_DIR}/config/bosh-lite.yml"
  export BUNDLE_GEMFILE="${CC_DIR}/Gemfile"

  bundle exec rake jobs:local[worker.0]
popd > /dev/null
