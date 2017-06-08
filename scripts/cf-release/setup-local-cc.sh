#!/usr/bin/env bash

bosh ssh api_z1 0 <<'ENDSSH'
  sudo sed -i -- 's#unix:/var/vcap/sys/run/cloud_controller_ng/cloud_controller\.sock#192\.168\.50\.1:9022#g' '/var/vcap/jobs/cloud_controller_ng/config/nginx.conf' && \
  sudo /var/vcap/bosh/bin/monit restart nginx_cc
ENDSSH

if ! cat /etc/hosts | grep "blobstore.service.cf.internal" > /dev/null; then
  echo "10.244.0.130 blobstore.service.cf.internal" | sudo tee -a /etc/hosts > /dev/null
fi

if ! cat /etc/hosts | grep "bbs.service.cf.internal" > /dev/null; then
  echo "10.244.16.2 bbs.service.cf.internal" | sudo tee -a /etc/hosts > /dev/null
fi

if ! cat /etc/hosts | grep "bits-service.service.cf.internal" > /dev/null; then
  echo "10.244.0.74 bits-service.service.cf.internal" | sudo tee -a /etc/hosts > /dev/null
fi

if ! cat /etc/hosts | grep "bits-service.bosh-lite.com" > /dev/null; then
  echo "10.244.0.74 bits-service.bosh-lite.com" | sudo tee -a /etc/hosts > /dev/null
fi

if ! cat /etc/hosts | grep "uaa.service.cf.internal" > /dev/null; then
  echo "10.244.0.134 uaa.service.cf.internal" | sudo tee -a /etc/hosts > /dev/null
fi

if ! cat /etc/hosts | grep "loggregator-trafficcontroller.service.cf.internal" > /dev/null; then
  echo "10.244.0.150 loggregator-trafficcontroller.service.cf.internal" | sudo tee -a /etc/hosts > /dev/null
fi
