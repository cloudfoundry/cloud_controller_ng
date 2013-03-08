[![Build Status](https://travis-ci.org/cloudfoundry/cloud_controller_ng.png)](https://travis-ci.org/cloudfoundry/cloud_controller_ng)

# cloud_controller_ng

This repository contains the code for the Cloud Controller. The NG signifies that this is a "next generation" component and this is not backward-compatible with the original cloud_controller. 
This version adds significant new functionality including the additional manditory constructs of the "organization" and "space" heirarchy that all users, applications and services must use.

## Components

### Cloud Controller

The Cloud Controller itself is written in Ruby and provides the public API endpoint for Cloud Foundry that
reads and writes in the system. The Cloud Controller maintains a database with tables for orgs, spaces, apps,
services, service instances, user roles, and more. 

### Database (CC_DB)

The Cloud Controller database has been tested with Postgres or MySQL.

### Blob Store

The Cloud Controller manages a blob store for:

- resources - files that are uploaded to the Cloud Controller with a unique SHA such that they can be reused without re-uploading the file
- app packages - unstaged files that represent an application
- droplets - the result of taking an app package and staging it (processesing a buildpack) and getting it ready to run

The blob store uses [FOG][fog] such that it can use abstractions like s3 or a local file system mounted by NFS.

[fog]: http://fog.io/

#### NATS Messaging

The Cloud Controller interacts with other components using the NATS messaging bus.

- Instructs a DEA to stage an application (processes a buildpack for the app) to prepare it to run
- Instructs a DEA to start or stop an application
- Receives information from the Health Manager about applications
- Subscribes to Service Gateways that advertise available services
- Instructs Service Gateways to handle provisioning, unprovision, bind and unbind operations for services
