### Apply a manifest to a space

```
Example Request
```

```shell
curl "https://api.example.org/v3/spaces/[guid]/actions/apply_manifest" \
  -X POST \
  -H "Authorization: bearer [token]" \
  -H "Content-type: application/x-yaml" \
  --data-binary @/path/to/manifest.yml
```

```
Example Response
```

```http
HTTP/1.1 202 Accepted
Location: https://api.example.org/v3/jobs/[guid]
```

Apply changes specified in a manifest to the named apps and their underlying
processes. The apps must reside in the space. These changes are additive
and will not modify any unspecified properties or remove any existing
environment variables, routes, or services.

<aside class="notice">
Apply manifest will only trigger an immediate update for the "disk_quota", "instances", and "memory" properties. All other properties require an app restart to take effect.
</aside>

#### Definition
`POST /v3/spaces/:guid/actions/apply_manifest`

#### Permitted roles
 |
--- | ---
Admin |
Space Developer |
