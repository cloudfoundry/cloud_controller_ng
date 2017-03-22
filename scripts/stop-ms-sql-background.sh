#!/usr/bin/env bash

set -e

echo "Stopping MS SQL Server in the background..."
docker stop $(docker ps --filter ancestor='microsoft/mssql-server-linux' --format "{{.ID}}")

echo "MS SQL Server is now stopped."
