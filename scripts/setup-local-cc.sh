#!/usr/bin/env bash

bosh ssh api_z1 0 <<'ENDSSH'
  sudo sed -i -- 's/10\.244\.0\.138/192\.168\.50\.1/g' '/var/vcap/jobs/route_registrar/config/registrar_settings.yml' && \
  sudo /var/vcap/bosh/bin/monit stop cloud_controller_ng && \
  sudo /var/vcap/bosh/bin/monit restart route_registrar
ENDSSH

if ! cat /etc/hosts | grep "blobstore.service.cf.internal" > /dev/null; then
  echo "10.244.0.130 blobstore.service.cf.internal" | sudo tee -a /etc/hosts > /dev/null
fi
