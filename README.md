[![Code Climate](https://api.codeclimate.com/v1/badges/aa47fb93c59ced5fcc4f/maintainability)](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng)
[![Code Climate](https://api.codeclimate.com/v1/badges/aa47fb93c59ced5fcc4f/test_coverage)](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng)
[![slack.cloudfoundry.org](https://slack.cloudfoundry.org/badge.svg)](https://cloudfoundry.slack.com/messages/capi/)

# Welcome to the Cloud Controller

## Helpful Resources
adasd
* [V3 API Docs](http://v3-apidocs.cloudfoundry.org)
* [V2 API Docs](http://apidocs.cloudfoundry.org)
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
 
Cloud Controller currently supports [webdav](http://www.webdav.org/) and the following [fog](http://fog.io) connectors: 

* Alibaba Cloud (Experimental)
* Azure
* Openstack
* Local (NFS)
* Google
* AWS

### Runtime

The Cloud Controller on VMs uses [Diego](https://github.com/cloudfoundry/diego-release) to stage and run apps and tasks.
See [Diego Design Notes](https://github.com/cloudfoundry/diego-design-notes) for more details.

## Contributing

Please read the [contributors' guide](https://github.com/cloudfoundry/cloud_controller_ng/blob/main/CONTRIBUTING.md) and the [Cloud Foundry Code of Conduct](https://cloudfoundry.org/code-of-conduct/)
### Predefined Development Environment

To commence your work in a fully equipped development environment, you have two main options:

1. **GitHub Codespaces**: GitHub Codespaces provisions a virtual machine with essential core services, such as S3 Blobstore, Database, and NGINX. It also establishes a connection that your IDE can use (VSCode is recommended). To initiate a codespace, click on the green button within the GitHub UI(upper right corner) and select the 'Codespaces' tab.

2. **Local Environment**: This option allows you to establish an environment on your local machine with the same core services as GitHub Codespaces, using Docker.

A script in the project's root directory provides convenient shortcuts to set up an environment locally:

```
Usage: ./devenv.sh COMMAND

Commands:
  create     - Setting up the development environment(containers)
  start      - Starting the development environment(containers), an existing fully set up set of containers must exist.
  stop       - Stopping but not removing the development environment(containers)
  destroy    - Stopping and removing the development environment(containers)
  runconfigs - Copies matching run configurations for intellij and vscode into the respective folders
  help       - Print this help text
```

To run this script, ensure the following are installed on your local system:

- Ruby (Refer to the .ruby-version file for the correct version)
- [Bundler](https://bundler.io/)
- [Docker](https://www.docker.com/) (Feature "Allow privileged port mapping" must be enabled in Avanced Options on Docker Desktop for Mac, docker must be accessable without root permissions)
- [Docker Compose](https://github.com/docker/compose)
- [PSQL CLI](https://www.postgresql.org/docs/current/app-psql.html)
- [MYSQL CLI](https://dev.mysql.com/doc/refman/8.0/en/mysql.html)
- [UAAC](https://github.com/cloudfoundry/cf-uaac)
- [yq 4+](https://github.com/mikefarah/yq)

Upon executing `./devenv.sh create`, the necessary containers will be set up and the databases will be initialized and migrated. 

As an optional step, execute `./devenv.sh runconfigs` to copy predefined settings and run configurations for this project into `.vscode` and `.idea` directories for VSCode and IntelliJ/RubyMine/JetBrains IDEs. These configurations are opinionated and, hence, not provided by default, but they do offer common configurations to debug `rspecs`, `cloud_controller`, `local_worker`, and `generic_worker`.

#### Credentials

This Setup automatically creates a user in UAA for login in the cloud_controller, and sets Passwords for Postgres and Mysql.
In case you need them to configure them somewhere else (e.g. database visualizers):
- Postgres: postgres:supersecret@localhost:5432
- MySQL: root:supersecret@127.0.0.1:3306
- UAA Admin: 
```bash
uaac target http://localhost:8080
uaac token client get admin -s "adminsecret"
```
- CF Admin:
```bash
cf api http://localhost
cf login -u ccadmin -p secret
```

#### Starting the Cloud Controller locally

When the Docker containers have been set up as described above, you can start the cloud controller locally. Start the main process with:
```
./bin/cloud_controller -c ./tmp/cloud_controller.yml
```
Then start a local worker:
```
CLOUD_CONTROLLER_NG_CONFIG=./tmp/cloud_controller.yml bundle exec rake jobs:local
```
Start a delayed_job worker:
```
CLOUD_CONTROLLER_NG_CONFIG=./tmp/cloud_controller.yml bundle exec rake jobs:generic
```
And finally start the scheduler:
```
CLOUD_CONTROLLER_NG_CONFIG=./tmp/cloud_controller.yml bundle exec rake clock:start
```

Known limitations:
- The [uaa_client_manager](https://github.com/cloudfoundry/cloud_controller_ng/blob/96c729fd116843ce06f40e7325a89f59b64d5f86/lib/services/sso/uaa/uaa_client_manager.rb#L29) requires SSL for UAA connections. The UAA instance in the Docker container provides however only plain http connections. You can set `http.use_ssl` to `false` as workaround.

### Unit Tests
**TLDR:** Always run `bundle exec rake` before committing

To maintain a consistent and effective approach to testing, please refer to [the spec README](spec/README.md) and
keep it up to date, documenting the purpose of the various types of tests.

By default `rspec` will randomly pick between postgres and mysql.

If postgres is not running on your OSX machine, you can start up a server by doing the following:
```
brew services start postgresql
createuser -s postgres
DB=postgres rake db:create
```

It will try to connect to those databases with the following connection string:

* postgres: `postgres://postgres@localhost:5432/cc_test`
* mysql: `mysql2://root:password@localhost:3306/cc_test`

To specify a custom username, password, host, or port for either database type, you can override the default
connection string prefix (the part before the `cc_test` database name) by setting the `MYSQL_CONNECTION_PREFIX`
and/or `POSTGRES_CONNECTION_PREFIX` variables. Alternatively, to override the full connection string, including 
the database name, you can set the `DB_CONNECTION_STRING` environment variable.  This will restrict you to only 
running tests in serial, however.

For example, to run unit tests in parallel with a custom mysql username and password, you could execute:
```
MYSQL_CONNECTION_PREFIX=mysql2://custom_user:custom_password@localhost:3306 bundle exec rake
```

The following are examples of completely fully overriding the database connection string:

    DB_CONNECTION_STRING="postgres://postgres@localhost:5432/cc_test" DB=postgres rake spec:serial
    DB_CONNECTION_STRING="mysql2://root:password@localhost:3306/cc_test" DB=mysql rake spec:serial

If you are running the integration specs (which are included in the full rake),
and you are specifying `DB_CONNECTION_STRING`, you will also
need to have a second test database with `_integration_cc` as the name suffix.

For example, if you are using:

    DB_CONNECTION_STRING="postgres://postgres@localhost:5432/cc_test"

You will also need a database called:

    `cc_test_integration_cc`

The command
```
rake db:create
```
will create the above database when the `DB` environment variable is set to postgres or mysql.
You should run this before running rake in order to ensure that the `cc_test` database exists.

#### Running tests on a single file

The development team typically will run the specs to a single file as (e.g.)

    bundle exec rspec spec/unit/controllers/runtime/users_controller_spec.rb

#### Running all the unit tests

    bundle exec rake spec

Note that this will run all tests in parallel by default. If you are setting a custom `DB_CONNECTION_STRING`,
you will need to run the tests in serial instead:

    bundle exec rake spec:serial

To be able to run the unit tests in parallel and still use custom connection strings, use the
`MYSQL_CONNECTION_PREFIX` and `POSTGRES_CONNECTION_PREFIX` environment variables described above.

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

