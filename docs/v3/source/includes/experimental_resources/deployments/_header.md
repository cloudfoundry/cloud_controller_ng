## Deployments

Deployments are objects that manage updates to applications with zero downtime.

They can either:

* Manage updating an app's [droplet](#droplets) directly after an application package is staged

* Roll an app back to a specific [revision](#revisions) along with its associated droplet


It is possible to use [rolling deployments](https://docs.cloudfoundry.org/devguide/deploy-apps/rolling-deploy.html) for
applications without incurring downtime. This is different from the traditional method of pushing app updates which performs start/stop deployments.

