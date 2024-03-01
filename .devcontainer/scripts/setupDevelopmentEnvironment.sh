#!/bin/bash
set -Eeuo pipefail
# shellcheck disable=SC2064
trap "pkill -P $$" EXIT

# Database Information
POSTGRES_CONNECTION_PREFIX="postgres://postgres:supersecret@localhost:5432"
MYSQL_CONNECTION_PREFIX="mysql2://root:supersecret@127.0.0.1:3306"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

setupPostgres () {
    export DB="postgres"
    # Parallel Test DBs
    export POSTGRES_CONNECTION_PREFIX
    bundle exec rake db:pick db:parallel:recreate
    # Sequential Test DBs
    export PGPASSWORD=supersecret
    psql -U postgres -h localhost -tc "SELECT 1 FROM pg_database WHERE datname = 'cc_test'" | grep -q 1 || psql -U postgres -h localhost -c "CREATE DATABASE cc_test"
    # Main DB
    export DB_CONNECTION_STRING="${POSTGRES_CONNECTION_PREFIX}/ccdb"
    bundle exec rake db:recreate db:migrate db:seed
}

setupMariadb () {
    export DB="mysql"
    # Parallel Test DBs
    export MYSQL_CONNECTION_PREFIX
    bundle exec rake db:pick db:parallel:recreate
    # Sequential Test DBs
    mysql -h 127.0.0.1 -u root -psupersecret -e "CREATE DATABASE IF NOT EXISTS cc_test;"
    # Main DB
    export DB_CONNECTION_STRING="${MYSQL_CONNECTION_PREFIX}/ccdb"
    bundle exec rake db:recreate db:migrate db:seed
}

# Install packages
bundle config set --local with 'debug'
bundle install

# Setup Containers
setupPostgres || tee tmp/fail &
setupMariadb || tee tmp/fail &

# CC config
mkdir -p tmp
cp -a config/cloud_controller.yml tmp/cloud_controller.yml

yq -i e '.external_domain="localhost"' tmp/cloud_controller.yml
yq -i e '.system_domain="localhost"' tmp/cloud_controller.yml

yq -i e '.login.url="http://localhost:8080"' tmp/cloud_controller.yml
yq -i e '.login.enabled=true' tmp/cloud_controller.yml

yq -i e '.nginx.use_nginx=true' tmp/cloud_controller.yml
yq -i e '.nginx.instance_socket=""' tmp/cloud_controller.yml

yq -i e '.logging.file="tmp/cloud_controller.log"' tmp/cloud_controller.yml
yq -i e '.telemetry_log_path="tmp/cloud_controller_telemetry.log"' tmp/cloud_controller.yml
TMPDIR=$(pwd)/tmp yq -i e '.directories.tmpdir=env(TMPDIR)' tmp/cloud_controller.yml;
yq -i e '.directories.diagnostics="tmp"' tmp/cloud_controller.yml
yq -i e '.security_event_logging.enabled=true' tmp/cloud_controller.yml
yq -i e '.security_event_logging.file="tmp/cef.log"' tmp/cloud_controller.yml

yq -i e '.uaa.url="http://localhost:8080"' tmp/cloud_controller.yml
yq -i e '.uaa.internal_url="http://localhost:8080"' tmp/cloud_controller.yml
yq -i e '.uaa.resource_id="cloud_controller"' tmp/cloud_controller.yml
yq -i e 'del(.uaa.symmetric_secret)' tmp/cloud_controller.yml

yq -i e '.resource_pool.fog_connection.provider="AWS"' tmp/cloud_controller.yml
yq -i e '.resource_pool.fog_connection.endpoint="http://localhost:9001"' tmp/cloud_controller.yml
yq -i e '.resource_pool.fog_connection.aws_access_key_id="minioadmin"' tmp/cloud_controller.yml
yq -i e '.resource_pool.fog_connection.aws_secret_access_key="minioadmin"' tmp/cloud_controller.yml
yq -i e '.resource_pool.fog_connection.aws_signature_version=2' tmp/cloud_controller.yml
yq -i e '.resource_pool.fog_connection.path_style=true' tmp/cloud_controller.yml

yq -i e '.packages.fog_connection.provider="AWS"' tmp/cloud_controller.yml
yq -i e '.packages.fog_connection.endpoint="http://localhost:9001"' tmp/cloud_controller.yml
yq -i e '.packages.fog_connection.aws_access_key_id="minioadmin"' tmp/cloud_controller.yml
yq -i e '.packages.fog_connection.aws_secret_access_key="minioadmin"' tmp/cloud_controller.yml
yq -i e '.packages.fog_connection.aws_signature_version=2' tmp/cloud_controller.yml
yq -i e '.packages.fog_connection.path_style=true' tmp/cloud_controller.yml

yq -i e '.droplets.fog_connection.provider="AWS"' tmp/cloud_controller.yml
yq -i e '.droplets.fog_connection.endpoint="http://localhost:9001"' tmp/cloud_controller.yml
yq -i e '.droplets.fog_connection.aws_access_key_id="minioadmin"' tmp/cloud_controller.yml
yq -i e '.droplets.fog_connection.aws_secret_access_key="minioadmin"' tmp/cloud_controller.yml
yq -i e '.droplets.fog_connection.aws_signature_version=2' tmp/cloud_controller.yml
yq -i e '.droplets.fog_connection.path_style=true' tmp/cloud_controller.yml

yq -i e '.buildpacks.fog_connection.provider="AWS"' tmp/cloud_controller.yml
yq -i e '.buildpacks.fog_connection.endpoint="http://localhost:9001"' tmp/cloud_controller.yml
yq -i e '.buildpacks.fog_connection.aws_access_key_id="minioadmin"' tmp/cloud_controller.yml
yq -i e '.buildpacks.fog_connection.aws_secret_access_key="minioadmin"' tmp/cloud_controller.yml
yq -i e '.buildpacks.fog_connection.aws_signature_version=2' tmp/cloud_controller.yml
yq -i e '.buildpacks.fog_connection.path_style=true' tmp/cloud_controller.yml

yq -i e '.cloud_controller_username_lookup_client_name="login"' tmp/cloud_controller.yml
yq -i e '.cloud_controller_username_lookup_client_secret="loginsecret"' tmp/cloud_controller.yml

# Wait for background jobs and exit 1 if any error happened
# shellcheck disable=SC2046
wait $(jobs -p)
test -f tmp/fail && rm tmp/fail && exit 1

trap "" EXIT