### Create a manifest diff for apps

```
Example Request
```

```shell
curl "https://api.example.org/v3/spaces/[guid]/manifest_diff" \
  -X POST \
  -H "Authorization: bearer [token]" \
  -d @/path/to/manifest.yml
```

```
Example Response
```

```http
HTTP/1.1 202 OK
Content-Type: application/json

{
  "diff": [
    {
      "op": "remove",
      "path": "/applications/0/routes/1",
      "was": {"route": "route.example.com"}
    },
    {
      "op": "add",
      "path": "/applications/1/buildpacks/2",
      "value": "java_buildpack"
    },
    {
      "op": "replace",
      "path": "/applications/2/processes/1/memory",
      "was": "256M",
      "value": "512M"
    }
  ]
}
```

Create a manifest diff for apps in the provided manifest and their underlying processes. Currently manifest_diff only supports version 1 manifests.

Manifests require the `applications` field.

#### Definition
`GET /v3/spaces/:guid/manifest_diff`

#### Permitted Roles
 |
--- | ---
Admin |
Space Developer |
