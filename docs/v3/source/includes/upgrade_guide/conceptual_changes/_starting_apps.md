### Starting Apps

In the V2 API, starting an app (`PUT /v2/apps/:GUID` with `state`: `STARTED`) will automatically stage new packages into droplets. In V3, [starting an app](#start-an-app) will only run the app's current droplet. This change gives clients more control over what package to stage and when to stage it.

To reproduce the V2 start behavior in V3:

![Start Diagram](start_diagram.png)

1. [List packages](#list-packages) and filter on package state with value `READY` and order by recency.
1. If a package has been turned into a droplet [(see this endpoint)](#list-droplets-for-a-package) this means it has been staged already. In V2 workflows, this would mean this package is what the current droplet is running.
1. Stage the package by [creating a build](#create-a-build). This turns your package into a droplet.
1. Update the app’s [current droplet](#set-current-droplet) to the selected droplet. This droplet will be run when the app starts.
1. Change the app’s state to [started](#start-an-app)

This gives V3 users more flexibility when managing applications. The following
diagram shows many different flows for starting an app.

![Start Flow](start_flows.png)

 Apps can upload multiple packages, stage multiple droplets, roll back to older droplets, and other complicated workflows.
