#!/usr/bin/env bash

RUN_DIR="/var/vcap/sys/run/cloud_controller_clock"
PIDFILE="${RUN_DIR}/cloud_controller_clock.pid"

source /var/vcap/packages/capi_utils/pid_utils.sh

if [ -f "${PIDFILE}" ]; then
  kill_and_wait "$PIDFILE" 30 &> /dev/null
fi

echo 0 # tell bosh not wait for anything
exit 0
