### Create a manifest diff for a space (experimental)

```
Example Request
```

```shell
curl "https://api.example.org/v3/spaces/[guid]/manifest_diff" \
  -X POST \
  -H "Content-Type: application/x-yaml" \
  -H "Authorization: bearer [token]" \
  --data-binary @/path/to/manifest.yml
```

```
Example Response
```

```http
HTTP/1.1 201 Created
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

This endpoint returns a JSON representation of the difference between the
provided manifest and the current state of a space.

Currently, this endpoint can only diff [version 1](#the-manifest-schema) manifests.

Docker passwords and userinfo in parsed buildpack URLs are redacted with
`***`. Credential maps (`credentials` and `cnb-credentials`) and entire service
binding `parameters` maps are replaced with `[PRIVATE DATA HIDDEN]`, including
when they appear inside added objects or arrays. Buildpack URL values that cannot
be parsed by Ruby's URI library are returned unchanged.

Environment differences are reported, but any `value` and `was` fields in those
operations are always replaced with `[PRIVATE DATA HIDDEN]`. To read environment
values, use the dedicated [get environment](#get-environment-for-an-app) endpoint.

##### The diff object

The diff object format is inspired by the [JSON Patch
specification](https://tools.ietf.org/html/rfc6902).

Name           | Type | Description
-------------- | ---- | -----------
**op** | _string_ | Type of change; valid values are `add`, `remove`, `replace`
**path** | _string_ | Path to changing manifest field
**was** | _any_ | For `remove` and `replace` operations, the previous value; otherwise key is omitted
**value** | _any_ | For `add` and `replace` operations, the new value; otherwise key is omitted

#### Definition
`POST /v3/spaces/:guid/manifest_diff`

#### Permitted roles
 |
--- | ---
Admin |
Space Developer |
