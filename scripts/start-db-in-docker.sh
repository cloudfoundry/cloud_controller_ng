#!/bin/bash

set -e -u

function bootDB {
  db="$1"
   
  launchDB="(/postgres-entrypoint.sh postgres &> /var/log/postgres-boot.log) &"
  testConnection="psql -h localhost -U postgres -c '\conninfo'"
  createTestDB="psql -h localhost -U postgres -c 'create database cc_test'"

  echo -n "booting ${db}"
  eval "$launchDB"
  for _ in $(seq 1 60); do
    if eval "${testConnection}" &> /dev/null; then
      break
    fi
    echo -n "."
    sleep 1
  done

  if eval "${testConnection}" &> /dev/null; then
    echo "connection established to ${db}"
  else 
    echo "unable to connect to ${db}"
    exit 1
  fi
}

function moreSetup {
  apt-get update
  apt-get install -y libpq-dev default-libmysqlclient-dev
  bundle install
  rake db:create
}

cd /cloud_controller_ng
export GOPATH=$PWD

bootDB "${DB:-"notset"}"
moreSetup
set +e
exec /bin/bash
