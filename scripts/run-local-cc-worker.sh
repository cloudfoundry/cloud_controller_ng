#!/usr/bin/env bash

scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cc_dir="$( cd "${scripts_dir}/.." && pwd )"
tmp_dir="${cc_dir}/tmp"

pushd "${cc_dir}" > /dev/null
  echo "Running local CC worker..."
  export CLOUD_CONTROLLER_NG_CONFIG="${tmp_dir}/local-cc/cloud_controller_ng.yml"
  export BUNDLE_GEMFILE="${cc_dir}/Gemfile"

  bundle exec rake jobs:local[worker.0]
popd > /dev/null
