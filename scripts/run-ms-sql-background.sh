#!/usr/bin/env bash

set -e

echo "Starting MS SQL Server in the background..."

docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=Password-123' -p 1433:1433 -d microsoft/mssql-server-linux
sleep 10 # mssql CLI hangs if connection is attempted immediately after starting server

echo "MS SQL Server is now running at localhost:1433"
