### Actions

Actions are API requests that are expected to immediately initiate change within the Cloud Foundry runtime. This is differentiated from requests which update a record but require additional updates, such as restarting an app, to cause changes to a resource to take effect.

Example:
```
POST /v3/apps/:guid/actions/start
```
