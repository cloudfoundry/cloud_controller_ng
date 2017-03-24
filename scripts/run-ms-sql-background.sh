#!/usr/bin/env bash

set -e

: ${LOG_FILE:=""}

echo "Starting MS SQL Server in the background..."

container_id="$(docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Password-123' -p 1433:1433 -d microsoft/mssql-server-linux)"
if [ -n "${LOG_FILE}" ]; then
  echo "Streaming MS SQL logs to '${LOG_FILE}'..."
  docker logs --follow "${container_id}" 2>&1 > "${LOG_FILE}" &
fi
sleep 10 # mssql CLI hangs if connection is attempted immediately after starting server

echo "MS SQL Server is now running at localhost:1433"
