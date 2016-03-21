#!/usr/bin/env bash

bosh ssh api_z1 0 <<'ENDSSH'
  sudo sed -i -- 's/192\.168\.50\.1/10\.244\.0\.138/g' '/var/vcap/jobs/route_registrar/config/registrar_settings.yml' && \
  sudo /var/vcap/bosh/bin/monit start cloud_controller_ng && \
  sudo /var/vcap/bosh/bin/monit restart route_registrar
ENDSSH

line_number=$(cat /etc/hosts | grep -n "blobstore.service.cf.internal" | cut -d : -f 1)

if [[ -n "${line_number}" ]]; then
  sed "${line_number}d" /etc/hosts | sudo tee /etc/hosts > /dev/null
fi
