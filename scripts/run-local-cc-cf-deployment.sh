#!/usr/bin/env bash

export RAILS_ENV=local

scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cc_dir="$( cd "${scripts_dir}/.." && pwd )"
tmp_dir="${cc_dir}/tmp"

pushd "${cc_dir}" > /dev/null
  echo "Running local CC..."
  bundle exec bin/cloud_controller -c "${tmp_dir}/local-cc-config.yml"
popd > /dev/null
