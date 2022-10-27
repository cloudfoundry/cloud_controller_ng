### Generate a manifest for an app

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
  stack: cflinuxfs3
  services:
  - my-service
  routes:
  - route: my-app.example.com
    protocol: http1
  processes:
  - type: web
    instances: 2
    memory: 512M
    log-rate-limit-per-second: 1KB
    disk_quota: 1024M
    health-check-type: port
```

Generate a manifest for an app and its underlying processes.

#### Definition
`GET /v3/apps/:guid/manifest`

#### Permitted roles
 |
--- | ---
Admin |
Admin Read-Only |
Space Developer |
