# Droplets

Droplets are created by staging an application package. There are two types
(lifecycles) of droplets: buildpack and docker. In the case of the buildpacks,
the droplet contains the bits produced by the buildpack, typically application
code and dependencies.

After an application is created and packages are uploaded, a droplet must be
created in order for an application to be deployed or tasks to be run. 
The current droplet [must be assigned](#set-current-droplet-for-an-app) to an 
application before it may be started. When [tasks are created](#create-a-task), 
they either use a specific droplet guid, or use the current droplet assigned to an application.

