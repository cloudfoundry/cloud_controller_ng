## Buildpacks

Buildpacks are used during a [build][builds]
to download external dependencies
and transform a [package][packages]
into an executable [droplet][droplets].
In this way, buildpacks are a pluggable extension to Cloud Foundry
that enable CF to run different languages and frameworks.
Buildpacks will automatically detect if they support an application.
Buildpacks can also be explicitly specified on [apps][] and [builds][].

[apps]: #apps
[builds]: #builds
[droplets]: #droplets
[packages]: #packages
