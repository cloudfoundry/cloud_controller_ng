#!/usr/bin/env bash

bosh ssh api_z1 0 <<'ENDSSH'
  sudo sed -i -- 's/10\.244\.0\.138/192\.168\.50\.1/g' '/var/vcap/jobs/route_registrar/config/registrar_settings.yml' && \
  sudo sed -i -- 's/9022/8181/g' '/var/vcap/jobs/route_registrar/config/registrar_settings.yml' && \
  sudo /var/vcap/bosh/bin/monit stop cloud_controller_ng && \
  sudo /var/vcap/bosh/bin/monit restart route_registrar
ENDSSH
