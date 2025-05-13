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
  stack: cflinuxfs4
  features:
    ssh: true
    revisions: true
    service-binding-k8s: false
    file-based-vcap-services: false
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
    health-check-type: http
    health-check-http-endpoint: /healthy
    health-check-invocation-timeout: 10
    health-check-interval: 5
    readiness-health-check-type: http
    readiness-health-check-http-endpoint: /ready
    readiness-health-check-invocation-timeout: 20
    readiness-health-check-interval: 5
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
