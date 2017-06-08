#!/usr/bin/env bash

set -eu

: "${BOSH_ENVIRONMENT:?}"
: "${BOSH_CLIENT:?}"
: "${BOSH_CLIENT_SECRET:?}"
: "${BOSH_DEPLOYMENT:="cf"}"
: "${BOSH_API_INSTANCE:="api/0"}"

scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cc_dir="$( cd "${scripts_dir}/.." && pwd )"
tmp_dir="${cc_dir}/tmp"

echo "Resetting nginx to original socket..."
bosh ssh "${BOSH_API_INSTANCE}" -c "\
  sudo sed -i -- 's/192\.168\.50\.1:9022/unix:\/var\/vcap\/sys\/run\/cloud_controller_ng\/cloud_controller\.sock/g' '/var/vcap/jobs/cloud_controller_ng/config/nginx.conf' && \
  sudo /var/vcap/bosh/bin/monit restart nginx_cc" > /dev/null

echo "Removing internal hostnames from /etc/hosts..."
sudo sed -i.bak "/.*\.service\.cf\.internal/d" /etc/hosts > /dev/null

echo "Removing local config files..."
rm -rf "${tmp_dir}/local-cc/"

echo "Done"
