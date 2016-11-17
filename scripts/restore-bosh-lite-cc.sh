#!/usr/bin/env bash

bosh ssh api_z1 0 <<'ENDSSH'
  sudo sed -i -- 's/192\.168\.50\.1/10\.244\.0\.138/g' '/var/vcap/jobs/route_registrar/config/registrar_settings.yml' && \
  sudo /var/vcap/bosh/bin/monit start cloud_controller_ng && \
  sudo /var/vcap/bosh/bin/monit start cloud_controller_worker_local_1 && \
  sudo /var/vcap/bosh/bin/monit start cloud_controller_worker_local_2 && \
  sudo /var/vcap/bosh/bin/monit restart route_registrar
ENDSSH

sed "/blobstore.service.cf.internal/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
sed "/bbs.service.cf.internal/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
sed "/bits-service.service.cf.internal/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
sed "/bits-service.bosh-lite.com/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
