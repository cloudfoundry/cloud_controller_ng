
### The lifecycle object

Lifecycle objects inform the platform how to build droplets and run apps. For example the the 
`buildpack` lifecycle will use a droplet on top of a rootfs to run the app, while a `docker` lifecycle will
pull a docker image from a registry to run an app.

Name | Type | Description
---- | ---- | -----------
**type** | _string_ | Type of the lifecycle. Valid values are `buildpack`, `docker`.
**data** | _object_ | Data that is used during staging and running for a lifecycle.

#### Buildpack lifecycle object 

Name | Type | Description
---- | ---- | -----------
**type** | _string_ | `buildpack`
**data.buildpacks** | _array of strings_ | A list of the names of buildpacks, URLs from which they may be downloaded, or null to auto-detect a suitable buildpack. Supports at most one buildpack.
**data.stack** | _string_ | The root filesystem to use with the buildpack, for example `cflinuxfs2`

#### Docker lifecycle object

Name | Type | Description
---- | ---- | -----------
**type** | _string_ | `docker`
**data** | _object_ | Data is not used by the docker lifecycle. Valid value is `{}`.
