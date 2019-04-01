### Generate an app manifest

Generate a manifest for an app and its underlying processes.

```
Example Request
```

```shell
curl "https://api.example.org/v3/apps/[guid]/manifest" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 200 OK
Content-Type: application/x-yaml

---
applications:
- name: my-app
  stack: cflinuxfs2
  routes:
  - route: my-app.example.com
  processes:
  - type: web
    instances: 2
    memory: 512M
    disk_quota: 1024M
    health-check-type: port
```

#### Definition
`GET /v3/apps/:guid/manifest`

#### Permitted Roles
 |
--- | ---
Space Developer |
Admin |
Admin Read-Only |
