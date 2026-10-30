# Internal API Docs

## Introduction

CC's internal API is a patchwork of endpoints used by internal components.
They evolved over time and were individually designed for specific purposes.
We do not recommend using internal API endpoints for anything other than their intended purposes.

## Auth and routing

In capi-release, nginx (`jobs/cloud_controller_ng/templates/nginx.conf.erb`) fronts CC and terminates TLS/mTLS, then reverse-proxies to the CC app over a unix socket. Each endpoint below carries a **Routing** line naming the nginx listener it is served on. The listeners (default ports; all configurable via BOSH properties):

| Listener | Property (default) | Auth | Serves |
|----------|--------------------|------|--------|
| mTLS internal | `cc.tls_port` (9023) | mTLS (`ssl_verify_client on`) | `/internal/v4/`, `/internal/v5/`, staging completion + upload regexes |
| Public TLS | `cc.public_tls.port` (9024) | in-app (OAuth) / staging basic auth | All public API routes; `/internal/v...` is 403'd here |
| Metrics mTLS | `cc.prom_metrics_server_tls_port` (9025) | mTLS (separate cert) | `/internal/v4/metrics` only |
| Status | `9021` (hardcoded) | none (loopback) | `/internal/v4/status` health check only |

The public TLS listener (9024) serves all public API routes. Gorouter registers it for the `api` route.

Auth mechanisms below:

- **mTLS** — Served on the mTLS internal listener (or the metrics listener for `/internal/v4/metrics`). An `/internal/*` path does not by itself imply mTLS — `ssh_access` is OAuth on the public listener, and `log_access` is mTLS **plus** an in-app OAuth check.
- **OAuth** — CC validates the UAA token's scope in-app; served on the public listeners.
- **Staging basic auth** — Enforced in-app by a Sinatra `before '/staging/*'` filter; served on the public listeners. Only works with a **local blobstore** (dev config) — production uses `storage-cli`, where Diego fetches a direct URL and nginx 403s `/staging/*`.

## Endpoints

### POST /internal/v3/staging/:staging_guid/build_completed
**Description:** Marks build as completed or failed.

**Intended Consumer:** Diego staging task completion callback

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### GET /internal/apps/:guid/ssh_access/:index
**Description:** Check if a user is able to ssh into a process container

**Intended Consumer:** SSH Proxy

**Auth Mechanism:** mTLS and OAuth. The SSH Proxy authenticates with a client certificate on the mTLS listener (`cc.tls_port`, default `9023`). The path `/internal/apps/...` does not match the public listener's `/internal/v` forbid rule, so it is also reachable on the public TLS listener (`cc.public_tls.port`, default `9024`) via OAuth.

**Routing:** mTLS internal listener (`cc.tls_port`, 9023) and public TLS listener (`cc.public_tls.port`, 9024).

### GET /v2/buildpacks/:guid/download
**Description:** Download a buildpack file. Note: this is a `/v2` public-namespace path (served on the public listener), not an `/internal/*` endpoint — its `download` action is exempt from user OAuth and gated by staging basic auth instead.

**Intended Consumer:** Diego staging task (local blobstore; remote blobstores get a direct signed URL and bypass this endpoint)

**Auth Mechanism:** Staging basic auth

**Routing:** Public TLS listener (`cc.public_tls.port`, 9024)

### GET /staging/packages/:guid
**Description:** Download a package if the blobstore is local (see "Staging basic auth" above)

**Intended Consumer:** Diego staging task

**Auth Mechanism:** Staging basic auth

**Routing:** Public TLS listener (`cc.public_tls.port`, 9024)

### GET /staging/v3/droplets/:guid/download
**Description:** Download a droplet if the blobstore is local (see "Staging basic auth" above)

**Intended Consumer:** Diego running task or process

**Auth Mechanism:** Staging basic auth

**Routing:** Public TLS listener (`cc.public_tls.port`, 9024)

### GET /staging/v3/buildpack_cache/:stack/:app_guid/download
**Description:** Download buildpack cache for a given stack and app combination if the blobstore is local (see "Staging basic auth" above)

**Intended Consumer:** Diego staging task

**Auth Mechanism:** Staging basic auth

**Routing:** Public TLS listener (`cc.public_tls.port`, 9024)

### GET /internal/v4/droplets/:guid/:droplet_checksum/download
**Description:** Permalink for downloading a droplet.

**Intended Consumer:** Diego running task or process

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### POST /internal/v4/apps/:process_guid/crashed
**Description:** Create crash audit event for process

**Intended Consumer:** TPS Watcher

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### POST /internal/v4/apps/:process_guid/readiness_changed
**Description:** Records a process readiness-changed event (`APP_PROCESS_READY` / `APP_PROCESS_NOT_READY`)

**Intended Consumer:** TPS Watcher

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### POST /internal/v4/apps/:process_guid/rescheduling
**Description:** Records an `APP_PROCESS_RESCHEDULING` audit event

**Intended Consumer:** TPS Watcher

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### GET /internal/v4/log_access/:app_guid
**Description:** Check if a user has access to the log stream for an app

**Intended Consumer:** Loggregator (Traffic Controller, RLP Gateway)

**Auth Mechanism:** mTLS + OAuth (dual auth)

**Routing:** mTLS internal listener (`cc.tls_port`, 9023). Unlike other `/internal/v4/` endpoints, the app adds an in-app UAA scope check on top of nginx mTLS — the consumer presents both.

### GET /internal/v5/syslog_drain_urls
**Description:** Return list of syslog drain urls from logging services.

**Intended Consumer:** Loggregator (syslog-binding-cache)

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### POST /internal/v4/tasks/:task_guid/completed
**Description:** Marks task as complete

**Intended Consumer:** Diego (task completion callback)

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### POST /internal/v4/droplets/:guid/upload
**Description:** Uploads droplet

**Intended Consumer:** CC Uploader

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### GET /internal/v4/staging_jobs/:guid
**Description:** Returns progress of droplet upload job

**Intended Consumer:** CC Uploader

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### POST /internal/v4/buildpack_cache/:stack_name/:guid/upload
**Description:** Uploads buildpack cache for a stack name and app guid

**Intended Consumer:** CC Uploader

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

### GET /internal/v4/metrics
**Description:** Returns CAPI metrics

**Intended Consumer:** Prom Scraper

**Auth Mechanism:** mTLS

**Routing:** Metrics mTLS listener (`cc.prom_metrics_server_tls_port`, 9025)

### GET /internal/v4/asg_latest_update
**Description:** Returns timestamp of the last Application Security Group update

**Intended Consumer:** cf-networking policy-server (ASG syncer)

**Auth Mechanism:** mTLS

**Routing:** mTLS internal listener (`cc.tls_port`, 9023)

## Deprecated endpoints

These endpoints are deprecated and have no known live consumer. They are removal candidates.
