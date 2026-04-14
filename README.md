[![Code Climate](https://api.codeclimate.com/v1/badges/aa47fb93c59ced5fcc4f/maintainability)](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng)
[![Code Climate](https://api.codeclimate.com/v1/badges/aa47fb93c59ced5fcc4f/test_coverage)](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng)
[![slack.cloudfoundry.org](https://slack.cloudfoundry.org/badge.svg)](https://cloudfoundry.slack.com/messages/capi/)

# Welcome to the Cloud Controller

## Helpful Resources

* [V3 API Docs](http://v3-apidocs.cloudfoundry.org)
* [V2 API Docs](http://v2-apidocs.cloudfoundry.org)
* [Continuous Integration Pipelines](https://concourse.app-runtime-interfaces.ci.cloudfoundry.org/teams/capi-team)
* [Notes on V3 Architecture](https://github.com/cloudfoundry/cloud_controller_ng/wiki/Notes-on-V3-Architecture)
* [capi-release](https://github.com/cloudfoundry/capi-release) - The bosh release used to deploy cloud controller

## Components

### Cloud Controller

The Cloud Controller provides REST API endpoints to create and manage apps, services, user roles, and more!

### Database

The Cloud Controller supports Postgres and Mysql.

### Blobstore

The Cloud Controller manages a blobstore for:

All Platforms:
* Resource cache: During package upload resource matching, Cloud Controller will only upload files it doesn't already have in this cache.

When deployed via capi-release only:
* App packages: Unstaged files for an application
* Droplets: An executable containing an app and its runtime dependencies
* Buildpacks: Set of programs that transform packages into droplets
* Buildpack cache: Cached dependencies and build artifacts to speed up future staging

#### Providers

| Provider | `blobstore_type` | Backends | Notes |
|----------|------------------|----------|-------|
| Storage CLI | `storage-cli` | S3, S3-compatible, GCS, Azure, Alibaba Cloud | |
| Fog | `fog` | AWS, Azure, GCS, Alibaba Cloud, OpenStack, Local/NFS | **Default.** Local/NFS not recommended for production |
| WebDAV | `webdav` | WebDAV servers | |
| Local | `local`, `local-temp-storage` | Filesystem, NFS | Development and testing only |

### Runtime

The Cloud Controller on VMs uses [Diego](https://github.com/cloudfoundry/diego-release) to stage and run apps and tasks.
See [Diego Design Notes](https://github.com/cloudfoundry/diego-design-notes) for more details.

## Contributing

Please read the [contributors' guide](https://github.com/cloudfoundry/cloud_controller_ng/blob/main/CONTRIBUTING.md) and the [Cloud Foundry Code of Conduct](https://cloudfoundry.org/code-of-conduct/)

### Development Environment Setup

#### Option 1: Devcontainer

- **GitHub Codespaces:** Click "Code" → "Codespaces" → "Create codespace"
- **VS Code:** Open folder → "Reopen in Container"

Other IDEs with devcontainer support (e.g., IntelliJ) may work but are not tested.

Everything autoconfigures. After setup completes, use VS Code's **Run/Debug panel** (see `.vscode/launch.json`) or run manually:
```bash
cc-generate-config             # Generate cloud_controller.yml
eval "$(cc-db-env psql ccdb)"  # Set database env vars
cloud_controller -c tmp/.dev-generated/cloud_controller.devcontainer.yml
cflogin                        # Authenticate CF CLI (alias for cf api + auth)
```

#### Option 2: Local Development

**Prerequisites:** Ruby (see `.ruby-version` for correct version), [Bundler](https://bundler.io/), [Docker Desktop](https://www.docker.com/products/docker-desktop/), [direnv](https://direnv.net/), [PSQL](https://www.postgresql.org) and/or [MySQL](https://dev.mysql.com/doc/mysql-shell/en/).

```bash
direnv allow                    # Enable direnv (adds cc-* scripts to PATH)
bundle install                  # Install gems
cc-containers start             # Start DBs + UAA + nginx
cc-generate-config              # Generate cloud_controller.yml
eval "$(cc-db-env psql ccdb)"   # Set database env vars
cc-reset-db                     # (re)create and migrate databases
cc-setup-ide                    # Copy IDE run/debug configs (optional)
```

Then see [Running Cloud Controller](#running-cloud-controller) below.

#### Helper Scripts

All scripts are prefixed with `cc-` and added to PATH via direnv:

| Script | Purpose |
|--------|---------|
| `cc-containers <cmd>` | Manage Docker containers (see below) |
| `cc-db-env <db> <schema>` | Set `DB_CONNECTION_STRING` and `CLOUD_CONTROLLER_NG_CONFIG`. Usage: `eval "$(cc-db-env psql ccdb)"` |
| `cc-generate-config [mode]` | Generate cloud_controller.yml (modes: local-temp-storage, local, storage-cli) |
| `cc-reset-db` | Drop and recreate all databases |
| `cc-setup-ide` | Copy IDE configs (VS Code, IntelliJ) - won't overwrite existing |
| `cc-install-storage-cli` | Install storage-cli binary to tmp/bin/ (for S3 blobstore testing) |

**Container management** (or use `docker compose` directly with profiles: `dev`, `full`, `s3`):
```bash
cc-containers start           # DBs + UAA + nginx (typical dev)
cc-containers start minimal   # UAA + nginx only (for databases via brew)
cc-containers start full      # All services
cc-containers start s3        # Dev + SeaweedFS (S3 testing, local only)
cc-containers start broker    # Dev + CATS service broker
cc-containers stop            # Stop all
cc-containers logs [service]  # Follow logs
cc-containers status          # Show status
```

**Using brew databases instead of Docker:**
```bash
brew services start postgresql@16
brew services start mysql
cc-containers start minimal   # Only starts UAA + nginx
```

**S3 blobstore testing (local only):**

To test with S3-compatible storage via SeaweedFS:

```bash
cc-install-storage-cli                       # Downloads storage-cli to tmp/bin/
export STORAGE_CLI_PATH="$(pwd)/tmp/bin/storage-cli"  # Point CC to storage-cli binary
cc-containers start s3                       # Start dev profile + SeaweedFS
cc-generate-config storage-cli               # Generate config with storage-cli blobstore
eval "$(cc-db-env psql ccdb)"
cloud_controller -c tmp/.dev-generated/cloud_controller.local.yml
```

**Note:** S3/storage-cli mode is only available for local development, not in devcontainer due to SeaweedFS mount issues.

**Configuration:** Create `.envrc.local` (gitignored) for personal settings:
```bash
export PARALLEL_TEST_PROCESSORS=4  # Limit parallel test workers
```

#### Ports

| Service | Port | Notes |
|---------|------|-------|
| Cloud Controller | 3000 | Direct access without nginx |
| nginx | 80 | Proxies to CC, handles uploads |
| UAA | 8080 | |
| Postgres | 5432 | |
| MySQL | 3306 | |

#### Running Cloud Controller

Cloud Controller requires `DB_CONNECTION_STRING` and a config file. The easiest way is using `cc-db-env`:

```bash
eval "$(cc-db-env psql ccdb)"        # Sets DB_CONNECTION_STRING and CLOUD_CONTROLLER_NG_CONFIG
cloud_controller -c tmp/.dev-generated/cloud_controller.${CC_CONFIG}.yml

# In another terminal, start a worker for async jobs (e.g., buildpack uploads):
eval "$(cc-db-env psql ccdb)"
bundle exec rake jobs:local
```

Or set environment variables manually:
```bash
export DB_CONNECTION_STRING="postgres://postgres:supersecret@localhost:5432/ccdb"
cloud_controller -c tmp/.dev-generated/cloud_controller.local.yml
```

`CC_CONFIG` is `local` by default, `devcontainer` in devcontainer/codespaces.

#### CF CLI

```bash
# Devcontainer:
cflogin                               # Alias: cf api http://nginx && cf auth ccadmin secret

# Local (via nginx):
cf api http://localhost && cf auth ccadmin secret

# Local (direct, no nginx):
cf api http://localhost:3000 && cf auth ccadmin secret
```

#### Credentials

| Service | Connection |
|---------|------------|
| Postgres | `postgres://postgres:supersecret@localhost:5432` |
| MySQL | `mysql2://root:supersecret@localhost:3306` |
| CF Admin | `ccadmin` / `secret` |

### Running Tests

**TLDR:** Always run `bundle exec rake` before committing

To maintain a consistent and effective approach to testing, please refer to [the spec README](spec/README.md) and
keep it up to date, documenting the purpose of the various types of tests.

#### Database Configuration

The easiest way to configure the database for tests is using `cc-db-env`:

```bash
eval "$(cc-db-env psql test)"  # Configure for parallel tests with PostgreSQL
eval "$(cc-db-env mysql test)" # Configure for parallel tests with MySQL
```

Alternatively, you can set environment variables manually. By default rspec will randomly pick between postgres and mysql. It will try to connect with the following connection strings:

* postgres: `postgres://postgres@localhost:5432/cc_test`
* mysql: `mysql2://root:password@localhost:3306/cc_test`

To specify a custom username, password, host, or port for either database type, you can override the default
connection string prefix (the part before the `cc_test` database name) by setting the `MYSQL_CONNECTION_PREFIX`
and/or `POSTGRES_CONNECTION_PREFIX` variables. Alternatively, to override the full connection string, including
the database name, you can set the `DB_CONNECTION_STRING` environment variable. This will restrict you to only
running tests in serial, however.

For example, to run unit tests in parallel with a custom mysql username and password:
```
MYSQL_CONNECTION_PREFIX=mysql2://custom_user:custom_password@localhost:3306 bundle exec rake
```

Examples using `DB_CONNECTION_STRING` (serial only):
```
DB_CONNECTION_STRING="postgres://postgres@localhost:5432/cc_test" DB=postgres bundle exec rake spec:serial
DB_CONNECTION_STRING="mysql2://root:password@localhost:3306/cc_test" DB=mysql bundle exec rake spec:serial
```

#### Running tests on a single file

    bundle exec rspec spec/unit/controllers/runtime/users_controller_spec.rb

#### Running all the unit tests

    bundle exec rake spec

Note that this will run all tests in parallel by default. If you are setting a custom `DB_CONNECTION_STRING`,
you will need to run the tests in serial instead:

    bundle exec rake spec:serial

#### Running static analysis

    bundle exec rubocop

#### Running both unit tests and rubocop

By default, `bundle exec rake` will run the unit tests first, and then `rubocop` if they pass. To run `rubocop` first, run:

    RUBOCOP_FIRST=1 bundle exec rake

## Logs

Cloud Controller uses [Steno](http://github.com/cloudfoundry/steno) to manage its logs.
Each log entry includes a "source" field to designate which module in the code the
entry originates from.  Some of the possible sources are 'cc.app', 'cc.app_stager',
and 'cc.healthmanager.client'.

Here are some use cases for the different log levels:
* `error` - the CC received a malformed HTTP request, or a request for a non-existent droplet
* `warn` - the CC failed to delete a droplet, CC received a request with an invalid auth token
* `info` - CC received a token from UAA, CC received a NATS request
* `debug2` - CC created a service, updated a service
* `debug` - CC syncs resource pool, CC uploaded a file

## Configuration

The Cloud Controller uses a YAML configuration file. For an example, see `config/cloud_controller.yml`.

