## Stage a package

```
Definition
```

```http
POST /v3/packages/:guid/droplets HTTP/1.1
```

```
Example Request
```

```shell
curl "https://api.[your-domain.com]/v3/packages/[guid]/droplets" \
  -X POST \
  -H "Authorization: bearer [token]" \
  -d '{
    "environment_variables": {
      "CUSTOM_ENV_VAR": "hello"
    },
    "lifecycle": {
      "type": "buildpack",
      "data": {
        "buildpack": "http://github.com/myorg/awesome-buildpack",
        "stack": "cflinuxfs2"
      }
    }
  }'
```

```
Example Response
```

```http
HTTP/1.1 201 Created

{
  "guid": "whatuuid",
  "state": "PENDING",
  "error": null,
  "lifecycle": {
    "type": "buildpack",
    "data": {
      "buildpack": "http://github.com/myorg/awesome-buildpack",
      "stack": "cflinuxfs2"
    }
  },
  "staging_memory_in_mb": 1024,
  "staging_disk_in_mb": 4096,
  "result": {
    "buildpack": null,
    "stack": "cflinuxfs2",
    "process_types": null,
    "hash": {
      "type": "sha1",
      "value": null
    },
    "execution_metadata": null
  },
  "environment_variables":
  {
    "CUSTOM_ENV_VAR": "hello",
    "VCAP_APPLICATION": {
      "limits": {
        "mem": 1024,
        "disk": 4096,
        "fds": 16384
      },
      "application_id": "f82a88a2-2197-45b2-8b6d-84d1be8e2d0e",
      "application_version": "whatuuid",
      "application_name": "name-673",
      "application_uris": [ ],
      "version": "whatuuid",
      "name": "name-673",
      "space_name": "name-670",
      "space_id": "8543c9f2-0ec4-4bd2-adb4-eee7b2cd6c9d",
      "uris": [ ],
      "users": null
    },
    "CF_STACK": "cflinuxfs2",
    "MEMORY_LIMIT": 1024,
    "VCAP_SERVICES": { }
  },
  "created_at": "2015-11-03T00:53:54Z",
  "updated_at": null,
  "links": {
    "self": {
      "href": "/v3/droplets/whatuuid"
    },
    "package": {
      "href": "/v3/packages/aee22e31-6476-435e-a8c9-8961c6ead83e"
    },
    "app": {
      "href": "/v3/apps/f82a88a2-2197-45b2-8b6d-84d1be8e2d0e"
    },
    "assign_current_droplet": {
      "href": "/v3/apps/f82a88a2-2197-45b2-8b6d-84d1be8e2d0e/droplets/current",
      "method": "PUT"
    }
  }
}
```

This endpoint stages a package. Staging a package creates a droplet.

### Body Parameters

<ul class="method-list-group">
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      environment_variables

      <span class="method-list-item-type">optional</span>
    </h4>

    <p class="method-list-item-description">JSON object of environment variables to use during staging. Environment variable names may not start with "VCAP_" or "CF_". "PORT" is not a valid environment variable. Example environment variables: {"FEATURE_ENABLED": "true"}</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      staging_memory_in_mb

      <span class="method-list-item-type">optional</span>
    </h4>

    <p class="method-list-item-description">Memory limit used to stage package. Must be an integer.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      staging_disk_in_mb

      <span class="method-list-item-type">optional</span>
    </h4>

    <p class="method-list-item-description">Disk limit used to stage package. Must be an integer.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      lifecycle

      <span class="method-list-item-type">optional</span>
    </h4>

    <p class="method-list-item-description">JSON object of lifecycle information for a droplet. If not provided, it will default to a buildpack. Example lifecycle information: { "type": "buildpack", "data": { "buildpack": "http://github.com/myorg/awesome-buildpack", "stack": "cflinuxfs2" } }</p>
  </li>
</ul>
