[![Build Status](https://travis-ci.org/cloudfoundry/cloud_controller_ng.png)](https://travis-ci.org/cloudfoundry/cloud_controller_ng)
[![Code Climate](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng.png)](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng)
[![Test Coverage](https://codeclimate.com/repos/51c3523bf3ea005a650124e6/badges/da59f8dc2c9862d749c6/coverage.png)](https://codeclimate.com/repos/51c3523bf3ea005a650124e6/feed)
[![slack.cloudfoundry.org](https://slack.cloudfoundry.org/badge.svg)](https://cloudfoundry.slack.com/messages/capi/)

# API documentation

* [V3 API Docs](http://v3-apidocs.cloudfoundry.org)
* [V2 API Docs](http://apidocs.cloudfoundry.org)

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

* Azure
* Openstack
* Local (NFS)
* Google
* AWS

### Runtime

The Cloud Controller uses [Diego](https://github.com/cloudfoundry/diego-release) to stage and run apps and tasks.

See [Diego Design Notes](https://github.com/cloudfoundry/diego-design-notes) for more details.

## Contributing

Please read the [contributors' guide](https://github.com/cloudfoundry/cloud_controller_ng/blob/master/CONTRIBUTING.md)

### Testing
**TLDR:** Always run `bundle exec rake` before committing

To maintain a consistent and effective approach to testing, please refer to `spec/README.md` and
keep it up to date, documenting the purpose of the various types of tests.

By default `rspec` will randomly pick between postgres and mysql.

It will try to connect to those databases with the following connection string:
postgres: postgres://postgres@localhost:5432/cc_test
mysql: mysql2://root:password@localhost:3306/cc_test

rake db:create will create the above database when the `DB` environment variable is set to postgres or mysql.
You should run this before running rake in order to ensure that the `cc_test` database exists.

You can specify the full connection string via the `DB_CONNECTION_STRING`
environment variable. Examples:

    DB_CONNECTION_STRING="postgres://postgres@localhost:5432/cc_test" rake
    DB_CONNECTION_STRING="mysql2://root:password@localhost:3306/cc_test" rake

If you are running the integration specs (which are included in the full rake),
and you are specifying DB_CONNECTION_STRING, you will also
need to have a second test database with `_integration_cc` as the name suffix.

For example, if you are using:

    DB_CONNECTION_STRING="postgres://postgres@localhost:5432/cc_test"

You will also need a database called:

    `cc_test_integration_cc`

### Running tests on a single file

The development team typically will run the specs to a single file as (e.g.)

    bundle exec rspec spec/controllers/runtime/users_controller_spec.rb

### Running all the tests

    bundle exec rake spec

### Running static analysis

    bundle exec rubocop

## Logs

Cloud Controller uses [Steno](http://github.com/cloudfoundry/steno) to manage its logs.
Each log entry includes a "source" field to designate which module in the code the
entry originates from.  Some of the possible sources are 'cc.app', 'cc.app_stager',
'cc.dea.client' and 'cc.healthmanager.client'.

Here are some use cases for the different log levels:
* `error` - the CC received a malformed HTTP request, or a request for a non-existent droplet
* `warn` - the CC failed to delete a droplet, CC received a request with an invalid auth token
* `info` - CC received a token from UAA, CC received a NATS request
* `debug2` - CC created a service, updated a service
* `debug` - CC syncs resource pool, CC uploaded a file

## Configuration

The Cloud Controller uses a YAML configuration file. For an example, see `config/cloud_controller.yml`.

