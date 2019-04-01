## Builds

Builds represent the process of staging an application package. There are two types
([lifecycles](#lifecycles)) of builds: buildpack and docker.

After an [application](#apps) is created and [packages](#packages) are uploaded, a build
resource can be created to initiate the staging process. A successful build results in a 
[droplet](#droplets).

