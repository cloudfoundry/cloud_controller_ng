# Rolling Zero-Downtime Deployments

Cloud foundry now supports native rolling, zero-downtime deployments for applications.
The traditional `cf push` behavior is to upload your new code, 
stop the old version of the application,
and start the new version of the application.

## Enabling Deployments

Your cloudfoundry deployment must be using capi-release `0.168.0` or later.
On your computer, you must be using cf cli version `6.40.0` or later.
Additionally, the `cc_deployment_updater` must be deployed. 
See this [temporary ops file](https://github.com/cloudfoundry/cf-deployment/blob/master/operations/experimental/add-deployment-updater.yml) and the [external-db](https://github.com/cloudfoundry/cf-deployment/blob/master/operations/experimental/add-deployment-updater-external-db.yml) and [postgres](https://github.com/cloudfoundry/cf-deployment/blob/master/operations/experimental/add-deployment-updater-postgres.yml) variants.

## Deploying an App with Zero Downtime

To deploy an app without incurring downtime simply use the `cf v3-zdt-push` command.
Note that the default command will exit successfully after the first new instance is running, but before the deployment is completed.

 Example: `cf v3-zdt-push APP_NAME`

To make the cli wait for all instances to become healthy before exiting, use the `--wait-for-deploy-complete` flag.

 Example: `cf v3-zdt-push APP_NAME --wait-for-deploy-complete`

## Under the Hood

`cf v3-zdt-push` has two steps relevant to this feature:
1. Stage the app and create a droplet representing updated code for your application
1. Create a deployment with that droplet for your app 

The [deployment](http://v3-apidocs.cloudfoundry.org/version/3.58.0/index.html#the-deployment-object)
 can be seen with `cf curl /v3/deployments` and should have the state `DEPLOYING`


### Deployment Algorithm

1. A new deployment web process is created for the application with the new droplet and any new configuration.
This new process starts out with 1 instance and shares the route with the old web process.
If you run `cf app` on your application, you will see a `web` process and a `web-deployment-<deployment-guid>` process.
1. The `cc_deployment_updater` bosh job runs in the background, updating deployments:
   1. Add another instance of the new deployment web process and remove an instance from the original web process.
   This only happens if all instances of the new deployment web process are currently running.
   1. Repeat the above step until the new deployment web process has reached the desired number of instances for the application   
   1. Remove the old web process. The new deployment web process now fully replaces the old web process.
   1. Update all non-web processes with a restart
   1. Mark the deployment as `DEPLOYED`


## Canceling a Zero-Downtime Deployment

To stop a deployment:

```sh
cf v3-cancel-zdt-push APP_NAME
``` 

This will revert the application to the state it was before the deployment started.
This involves scaling up the original web process, removing any deployment artifacts,
and resetting the current_droplet on the application.

**There is no guarantee about zero-downtime during a cancel.** 
The goal is to revert to the original state as quickly as possible.

## Caveats

### There will be simultaneous versions of applications

During a deployment, both the old and new version of your application will be 
served at the same route.
This could lead to user issues if you push backwards-incompatible api changes.
Specifically, deployments do not specifically handle database migrations. 
If a migration from the new version of your app renders the old application inoperable,
you may still have downtime.

### Non-web processes have downtime

All non-web processes, such as worker processes,
will be restarted in bulk after the web processes have updated.
The zero-downtime guarantee is only for web processes.

### Quotas

A deployment will create an extra instance of your application, 
effectively serving as a canary instance.
This extra instance is still subject to quotas.
This means that an application that does not have enough quota 
to create an extra instance cannot be deployed in this fashion.
Administrators may need to allow for headroom in their quotas for deployments.

### Simultaneous deployments

It is possible to create a deployment for an app while another deployment for that app is in progress.
This will interrupt the prior deployment and eventually the application will be running with the newest code.
Until the last deployment is completed, there may be many versions of the application running all at once.
