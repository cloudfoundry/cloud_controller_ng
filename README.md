[![Build Status](https://travis-ci.org/cloudfoundry/cloud_controller_ng.png)](https://travis-ci.org/cloudfoundry/cloud_controller_ng)
[![Code Climate](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng.png)](https://codeclimate.com/github/cloudfoundry/cloud_controller_ng)

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

The Cloud Controller database has been tested with Postgres.

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
- Subscribes to Service Gateways that advertise available services
- Instructs Service Gateways to handle provisioning, unprovision, bind and unbind operations for services

## Testing

By default `rspec` will run test suite with sqlite3 in-memory database;
however, you can specify connection string via `DB_CONNECTION` environment
variable to test against postgres and mysql. Examples:

    DB_CONNECTION="postgres://postgres@localhost:5432/ccng" rspec
    DB_CONNECTION="mysql2://root:password@localhost:3306/ccng" rspec

Travis currently runs 3 build jobs against sqlite, postgres, and mysql.

## Logs

Cloud Controller uses [Steno](http://github.com/cloudfoundry/steno) to manage its logs.
Each log entry includes a "source" field to designate which module in the code the
entry originates from.  Some of the possible sources are 'cc.app', 'cc.app_stager',
'cc.dea.client' and 'cc.healthmanager.client'.

## Configuration

The Cloud Controller uses a YAML configuration file.
For an example, see `config/cloud_controller.yml`.
Some of the keys that are read from this configuration file are:

* `logging` - a [steno configuration hash](http://github.com/cloudfoundry/steno#from-yaml-file)
* `bulk_api` - basic auth credentials for the application state bulk API. In Cloud Foundry,
this endpoint is used by the health manager to retrieve the expected state of every user
application.
* `uaa` - URL and credentials for connecting to the [UAA](github.com/cloudfoundry/uaa),
Cloud Foundry's OAuth 2.0 server.
