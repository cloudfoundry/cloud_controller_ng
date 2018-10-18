[![Build Status](https://travis-ci.org/cloudfoundry/cloud_controller_ng.png)](https://travis-ci.org/cloudfoundry/cloud_controller_ng)
[![Code Climate](https://api.codeclimate.com/v1/badges/aa47fb93c59ced5fcc4f/maintainability)](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng)
[![Code Climate](https://api.codeclimate.com/v1/badges/aa47fb93c59ced5fcc4f/test_coverage)](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng)
[![slack.cloudfoundry.org](https://slack.cloudfoundry.org/badge.svg)](https://cloudfoundry.slack.com/messages/capi/)

# DO NOT MERGE THIS
# Welcome to the Cloud Controller

## Helpful Resources

* [V3 API Docs](http://v3-apidocs.cloudfoundry.org)
* [V2 API Docs](http://apidocs.cloudfoundry.org)
* [Continuous Integration Pipelines](https://capi.ci.cf-app.com)

## Components

### Cloud Controller

The Cloud Controller provides REST API endpoints to create and manage apps, services, user roles, and more!

### Database

The Cloud Controller supports Postgres and Mysql.

### Blobstore

The Cloud Controller manages a blobstore for:

* Resource cache: During package upload resource matching, Cloud Controller will only upload files it doesn't already have in this cache.
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

The Cloud Controller uses [Diego](https://github.com/cloudfoundry/diego-release) to stage and run apps and tasks.

See [Diego Design Notes](https://github.com/cloudfoundry/diego-design-notes) for more details.

## Contributing

Please read the [contributors' guide](https://github.com/cloudfoundry/cloud_controller_ng/blob/master/CONTRIBUTING.md) and the [Cloud Foundry Code of Conduct](https://cloudfoundry.org/code-of-conduct/)

### Unit Tests
**TLDR:** Always run `bundle exec rake` before committing

To maintain a consistent and effective approach to testing, please refer to [the spec README](spec/README.md) and
keep it up to date, documenting the purpose of the various types of tests.

By default `rspec` will randomly pick between postgres and mysql.

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

    bundle exec rspec spec/controllers/runtime/users_controller_spec.rb

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

### CF Acceptance Tests (CATs)

To ensure our changes to the Cloud Controller correctly integrate with the rest of the Cloud Foundry components like Diego,
we run the [CF Acceptance Tests (CATs)](https://github.com/cloudfoundry/cf-acceptance-tests) against a running CF deployment.
This test suite uses the CF CLI to ensure end-user actions like `cf push` function end-to-end.

For more substantial code changes and PRs, please deploy your changes and ensure that at least the core CATs suite passes.
Follow the instructions [here](https://github.com/cloudfoundry/cf-acceptance-tests#test-setup) for setting up the CATs suite.
The following will run the core test suites against a local bosh-lite:

```bash
cd ~/go/src/github.com/cloudfoundry/cf-acceptance-tests
cat > integration_config.json <<EOF
{
  "api": "api.bosh-lite.com",
  "apps_domain": "bosh-lite.com",
  "admin_user": "admin",
  "admin_password": "admin",
  "skip_ssl_validation": true
}
EOF
export CONFIG=$PWD/integration_config.json
./bin/test -nodes=3
```

If your change touches a more specialized part of the code such as Isolation Segments or Tasks,
please opt into the corresponding test suites.
The full list of optional test suites can be found [here](https://github.com/cloudfoundry/cf-acceptance-tests#test-configuration).

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

