[![Build Status](https://travis-ci.org/cloudfoundry/cloud_controller_ng.png)](https://travis-ci.org/cloudfoundry/cloud_controller_ng)
[![Code Climate](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng.png)](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng)
[![Test Coverage](https://codeclimate.com/repos/51c3523bf3ea005a650124e6/badges/da59f8dc2c9862d749c6/coverage.png)](https://codeclimate.com/repos/51c3523bf3ea005a650124e6/feed)

# cloud_controller_ng

This repository contains the code for the Cloud Controller. The NG signifies
that this is a "next generation" component and this is not backward-compatible
with the original cloud_controller. This version adds significant new
functionality including the additional mandatory "organization" and "space"
hierarchy that all users, applications and services must use.

## Components

### Cloud Controller

The Cloud Controller itself is written in Ruby and provides REST API endpoints
for clients to access the system. The Cloud Controller maintains a database with
tables for orgs, spaces, apps, services, service instances, user roles, and more.

### Database (CC_DB)

The Cloud Controller database has been tested with Postgres and Mysql.

### Blob Store

The Cloud Controller manages a blob store for:

- resources - files that are uploaded to the Cloud Controller with a unique SHA
  such that they can be reused without re-uploading the file

- app packages - unstaged files that represent an application

- droplets - the result of taking an app package and staging it
  (processesing a buildpack) and getting it ready to run

The blob store uses [FOG][fog] such that it can use abstractions like
Amazon S3 or an NFS-mounted file system for storage.

[fog]: http://fog.io/

## NATS Messaging

The Cloud Controller interacts with other core components of the Cloud Foundry
platform using the NATS message bus. For example, it performs the following using NATS:

- Instructs a DEA to stage an application (processes a buildpack for the app) to prepare it to run
- Instructs a DEA to start or stop an application
- Receives information from the Health Manager about applications

## Testing

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

## Static Analysis

To help maintain code consistency, rubocop is used to enforce code conventions and best practices.

### Running static analysis

    bundle exec rubocop

## API documentation

API documentation for the latest build of master can be found here: http://apidocs.cloudfoundry.org

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

### Database migration logs

The logs for database migrations are written to standard out.

## Configuration

The Cloud Controller uses a YAML configuration file.
For an example, see `config/cloud_controller.yml`.
Some of the keys that are read from this configuration file are:

* `logging` - a [steno configuration hash](http://github.com/cloudfoundry/steno#from-yaml-file)
* `bulk_api` - basic auth credentials for the application state bulk API. In Cloud Foundry,
this endpoint is used by the health manager to retrieve the expected state of every user
application.
* `uaa` - URL and credentials for connecting to the [UAA](http://github.com/cloudfoundry/uaa),
Cloud Foundry's OAuth 2.0 server.

## Contributing

Please read the [contributors' guide](https://github.com/cloudfoundry/cloud_controller_ng/blob/master/CONTRIBUTING.md)

