#!/usr/bin/env bash

export RAILS_ENV=local

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CC_DIR="${DIR}/../.."

pushd "${CC_DIR}" > /dev/null
  bundle exec bin/cloud_controller -c config/bosh-lite.yml
popd > /dev/null
