# Internal API Docs

## Introduction

CC's internal API is a patchwork of endpoints used by internal components. 
They evolved over time and were individually designed for specific purposes. 
We do not recommend using internal API endpoints for anything other than their intended purposes. 

## Endpoints

### POST /internal/v3/staging/:staging_guid/droplet_completed
**Description:** (Deprecated) Legacy endpoint used to mark droplet staging as complete. Use `POST /internal/v3/staging/:staging_guid/build_completed` instead.

**Intended Consumer:** Diego staging task completion callback

**Auth Mechanism:** MTLS + Basic Auth

### POST /internal/v3/staging/:staging_guid/build_completed
**Description:** Marks build as completed or failed.

**Intended Consumer:** Diego staging task completion callback

**Auth Mechanism:** MTLS + Basic Auth

### GET /internal/apps/:guid/ssh_access/:index
**Description:** Check if a user is able to ssh into a process container

**Intended Consumer:** SSH Proxy

**Auth Mechanism:** OAuth

### GET /v2/buildpacks/:guid/download
**Description:** Download a buildpack file

**Intended Consumer:** ??? (Probably intended for Diego staging task, but it looks like they use direct download from the blobstore now)

**Auth Mechanism:** Basic Auth

### GET /staging/packages/:guid
**Description:** Download a package if the blobstore is local (NFS server mounted on the CC)

**Intended Consumer:** Diego staging task

**Auth Mechanism:** Basic Auth

### GET /staging/v3/droplets/:guid/download
**Description:** Download a droplet if the blobstore is local (NFS server mounted on the CC)

**Intended Consumer:** Diego running task or process

**Auth Mechanism:** Basic Auth

### GET /staging/v3/buildpack_cache/:stack/:app_guid/download
**Description:** Download buildpack cache for a given stack and app combination

**Intended Consumer:** Diego staging task

**Auth Mechanism:** Basic Auth

### GET /internal/v2/droplets/:guid/:droplet_checksum/download
**Description:** (Deprecated) Permalink for downloading a droplet. Use `GET /internal/v4/droplets/:guid/:droplet_checksum/download` instead.

**Intended Consumer:** Diego running task or process

**Auth Mechanism:** None (redirects to MTLS endpoint if CC is configured for MTLS)

### GET /internal/v4/droplets/:guid/:droplet_checksum/download
**Description:** Permalink for downloading a droplet.

**Intended Consumer:** Diego running task or process

**Auth Mechanism:** MTLS

### POST /internal/v4/apps/:process_guid/crashed
**Description:** Create crash audit event for process

**Intended Consumer:** TPS Watcher

**Auth Mechanism:** MTLS

### GET /internal/v4/log_access/:app_guid
**Description:** Check if a user has access to the log stream for an app

**Intended Consumer:** Loggregator (`scheduler` and `syslog-binding-cache`)

**Auth Mechanism:** OAuth

### PATCH /internal/v4/packages/:guid
**Description:** Marks package as uploaded

**Intended Consumer:** Bits Service

**Auth Mechanism:** MTLS

### GET /internal/v4/syslog_drain_urls
**Description:** Return list of syslog drain urls from logging services

**Intended Consumer:** Loggregator

**Auth Mechanism:** MTLS

### POST /internal/v4/tasks/:task_guid/completed
**Description:** Marks task as complete

**Intended Consumer:** Application task running on Diego cell

**Auth Mechanism:** MTLS

### POST /internal/v4/droplets/:guid/upload
**Description:** Uploads droplet

**Intended Consumer:** CC Uploader

**Auth Mechanism:** MTLS + Basic Auth

### GET /internal/v4/staging_jobs/:guid
**Description:** Returns progress of droplet upload job

**Intended Consumer:** CC Uploader

**Auth Mechanism:** MTLS + Basic Auth

### POST /internal/v4/buildpack_cache/:stack_name/:guid/upload
**Description:** Uploads buildpack cache for a stack name and app guid

**Intended Consumer:** CC Uploader

**Auth Mechanism:** MTLS + Basic Auth


