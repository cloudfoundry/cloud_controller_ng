#!/bin/bash

set -e -u

SCRIPT_PATH="$(cd "$(dirname "${0}")" && pwd)"

function bootDB {
  db="$1"

  if [ "${db}" = "postgres" ]; then
    launchDB="(/postgres-entrypoint.sh postgres &> /var/log/postgres-boot.log) &"
    testConnection="psql -h localhost -U postgres -c '\conninfo'"
  elif [ "${db}" = "mysql" ]  || [ "${db}" = "mysql-5.6" ] || [ "${db}" = "mysql8" ]; then
    launchDB="(MYSQL_ROOT_PASSWORD=password /mysql-entrypoint.sh mysqld &> /var/log/mysql-boot.log) &"
    testConnection="mysql -h localhost -u root -D mysql -e '\s;' --password='password'"
  else
    echo "skipping database"
    return 0
  fi

  echo -n "booting ${db}"
  eval "$launchDB"
  for _ in $(seq 1 60); do
    if eval "${testConnection}" &> /dev/null; then
      echo "connection established to ${db}"
      return 0
    fi
    echo -n "."
    sleep 1
  done
  eval "${testConnection}" || true
  echo "unable to connect to ${db}"
  exit 1
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
exec /bin/bash "$@"
