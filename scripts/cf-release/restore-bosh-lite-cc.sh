#!/usr/bin/env bash

bosh ssh api_z1 0 <<'ENDSSH'
  sudo sed -i -- 's/192\.168\.50\.1:9022/unix:\/var\/vcap\/sys\/run\/cloud_controller_ng\/cloud_controller\.sock/g' '/var/vcap/jobs/cloud_controller_ng/config/nginx.conf' && \
  sudo /var/vcap/bosh/bin/monit restart nginx_cc
ENDSSH

sed "/blobstore.service.cf.internal/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
sed "/bbs.service.cf.internal/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
sed "/bits-service.service.cf.internal/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
sed "/bits-service.bosh-lite.com/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
sed "/uaa.service.cf.internal/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
sed "/loggregator-trafficcontroller.service.cf.internal/d" /etc/hosts | sudo tee /etc/hosts > /dev/null
