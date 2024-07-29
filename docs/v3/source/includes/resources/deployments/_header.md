## Deployments

Deployments are objects that manage updates to applications with zero downtime.

They can either:

* Manage updating an app's [droplet](#droplets) directly after an application package is staged

* Roll an app back to a specific [revision](#revisions) along with its associated droplet

Deployments are different than the traditional method of pushing app updates which performs start/stop deployments.

Deployment strategies supported:

* [Rolling deployments](https://docs.cloudfoundry.org/devguide/deploy-apps/rolling-deploy.html) allows for
applications to be deployed without incurring downtime by gradually rolling out instances.

* Canary deployments deploy a single instance and pause for user evaluation. If the canary instance is deemed successful, the deployment can be resumed via the [continue action](#continue-a-deployment). The deployment then continues like a rolling deployment. This feature is experimental and is subject to change.
