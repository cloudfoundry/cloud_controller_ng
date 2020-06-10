### Restage

The specialized `/v2/apps/:guid/restage` endpoint is replaced by the [builds](#builds) resource. Builds allow finer-grained
control and increased flexibility when staging packages into droplets. The V3 API avoids making assumptions about which 
package/droplet to use when staging or running an app and thus leaves it up to clients.

#### Replicating Restage

1. Get newest READY package for an app:

	`
	GET /v3/packages?app_guids=:app-guid&order_by=-created_at&states=READY
	`

2. Stage the package:

	`
	POST /v3/build
	`

1. Poll build until the state is `STAGED`:

	`
	GET /v3/builds/build-guid
	`

1. Stop the app:

	`
	POST /v3/apps/:guid/actions/stop
	`

1. Set the app's current droplet to the build's resulting droplet:

	`
	PATCH /v3/apps/:guid/relationships/current_droplet
	`

1. Start app:

	`
	POST /v3/apps/:guid/actions/start
	`

For a zero-downtime restage, you may wish to use [deployments](#deployments) instead of stopping and starting the app.


#### Restage Event

Since the V3 API has no concept of a "restage", the `audit.app.restage` audit
event is no longer reported. Instead, the following events can be tracked:

Audit Event|Description
---|---
audit.build.create | A build is created (staging is initiated)
audit.droplet.create | A droplet is created (staging finishes successfully)
audit.app.stop | Stopping an app is initiated
audit.app.droplet.mapped | A droplet is set as the current droplet for an app
audit.app.start | Starting an app is initiated
audit.app.deployment.create | A deployment is initialized

