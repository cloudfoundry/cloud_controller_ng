# Upgrade Guide

This document is intended to help client authors upgrade from Cloud Foundry's V2 API to the V3 API.

When moving to the V3 API, it is important to understand that the V3 API is backed by the same data as the V2 API. Though resources may be presented differently and have different interaction patterns, the internal state of CF will be the same across both APIs.

If you have questions, need help, or want to chat about the upgrade process, please reach out to us in [Cloud Foundry Slack](https://cloudfoundry.slack.com/messages/C07C04W4Q).

## Changed Resources

This table shows how V2 resources map to their respective V3 counterparts. Note that some V2 resources have split into multiple V3 resources, and some V2 resources have been combined into a single resource on V3. As these resources are currently under active development, these mappings may change.

|**V2 Resource(s)**|**V3 Resource(s)**|**Details**|
|---|---|---|
|Apps|Apps, Builds, Droplets, Packages, Processes|
|Buildpacks|Buildpacks|
|Domains, Shared Domains, Private Domains|Domains|[Domains in V3](#domains-in-v3)|
|Environment Variable Groups|Environment Variable Groups|
|Events|Audit Events|
|Feature Flags|Feature Flags|
|Jobs|Jobs|
|Organizations|Organizations|
|Quota Definitions|Organization Quotas|
|Resource Matches|Resource Matches|
|Routes, Route Mappings|Routes|[Routes in V3](#routes-in-v3)|
|Security Groups|Security Groups|
|Service Bindings, Service Keys|Service Keys|
|Service Brokers|Service Brokers|
|Service Instances, User-Provided Service Instances|Service Instances|
|Spaces|Spaces|
|Space Quota Definitions|Space Quotas|
|Stacks|Stacks|
|Usage Events|Usage Events|
|Users|Roles, Users|[Users and Roles in V3](#users-and-roles-in-v3)|

### Domains in V3

In V2, there were two types of domains exposed via different endpoints: private domains and shared domains.

In V3, there is only one domain resource. A domain is "shared" if it has an "owning organization", which is the organization in which the domain is accessible. This is represented as a relationship to this organization. A domain is "private" if it doesn't have this relationship.

Read more about the [domain resource](#domains).

### Routes in V3

In V2, the route resource represented a URL that could be mapped to an app, and the route mapping resource represented a mapping between a route and an app.

In V3, these concepts have been collapsed into a single route resource. Now, a route can have one or more "destinations" listed on it. These represent a mapping from the route to a resource that can serve traffic (e.g. a process of an app).

Read more about [routes and destinations](#routes).

### Users and Roles in V3

The user resource remains largely unchanged from the v2 API. On v2, `GET /v2/users` was restricted to admins, and other users needed to use nested endpoints (`GET /v2/organizations/:guid/user` and `GET /v2/spaces/:guid/user`) to view user resources. On v3, `GET /v3/users` is now available for all users, similar to other resources. Note that this does not change what user resources are visible.

In V2, roles were modeled as associations between organization and space endpoints. In V3, roles have a dedicated resource: `/v3/roles`. This has changed the manner in which roles are assigned. For example, in V2, to assign a user the `org_manager` role, one would `PUT /v2/organizations/:org_guid/managers/:user_id`. In V3, one would `POST /v3/roles` with the role type and relationships to the user and organization.

Read more about [users](#users) and [roles](#roles).

## Conceptual Changes

### App Sub-Resources

The V2 API rolls up several resources into its representation of an "app":

1. **Packages:** Source assets for the application
2. **Droplets:** Staged, executable assets for the application
3. **Builds:** Configuration for how to stage the package into a droplet
4. **Processes:** Configuration for how to run the droplet

The V3 API exposes these resources on the API to provide more visibility and enable more complicated workflows. For example:

1. Staging a previous package into a new droplet
2. Rolling back to a previous droplet
3. Staging a droplet to run a task, without running any processes
4. Running multiple different processes from a single droplet (for example: a web process and a worker process)

Here are some examples of implications for clients:

1. The app resource contains much less information about the application as a whole
2. An application can have multiple processes, each with their own start command, scale, and stats
3. An application might not be running with its most recent package or droplet

### Asynchronous Operations

Unlike V2, clients cannot opt-in for asynchronous responses from endpoints. Instead, endpoints that require asynchronous processing will return `202 Accepted` with a Location header pointing to the job resource to poll. Endpoints that do not require asynchronous processing will respond synchronously.

For clients that want to report the outcome of an asynchronous operation, the expected pattern is to poll the job in the Location header until its `state` is no longer `PROCESSING`. If the job's `state` is `FAILED`, the `errors` field will contain any errors that occurred during the operation.

An example of an asynchronous endpoint is the [delete app endpoint](#delete-an-app).

Read more about [the job resource](#jobs).

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="errors-v3">Errors</h3>

```
Example Request
```

```shell
curl "https://api.example.org/v2/apps/not-found" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 404 Not Found
Content-Type: application/json

{
   "description": "The app could not be found: not-found",
   "error_code": "CF-AppNotFound",
   "code": 100004
}
```

```
Example Request
```

```shell
curl "https://api.example.org/v3/apps/not-found" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 404 Not Found
Content-Type: application/json

{
   "errors": [
      {
         "detail": "App not found",
         "title": "CF-ResourceNotFound",
         "code": 10010
      }
   ]
}
```

The V3 API returns an array of errors instead of a single error like in V2.

Clients may wish to display all returned errors.

### Filtering

```
Filters are specified as individual query parameters in V3
```

```shell
curl "https://api.example.org/v2/apps?q=name+IN+dora,broker;stack:cflinuxfs3" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```shell
curl "https://api.example.org/v3/apps?names=dora,broker&stacks=cflinuxfs3" \
  -X GET \
  -H "Authorization: bearer [token]"
```

Filtering resources no longer uses V2's query syntax. See the example to the right.

A few common filters have been also renamed in V3:

|V2 filter|V3 filter|
|---|---|
|`results-per-page`|`per_page`|
|`page`|`page`|
|`order-by`|`order_by`|
|`order-direction`|N/A<sup>1</sup>|

<sup>1</sup> In V3, order is ascending by default. Prefix the `order_by` value with `-` to make it descending. For example, `?order_by=-name` would order a list of resources by `name` in descending order.

Read more about [filtering in V3](#filtering).

### Including Associated Resources

The `inline-relations-depth` parameter is no longer supported on V3. Instead, some resources support the `include` parameter to selectively include associated resources in the response body.

For example, to include an app's space in the response:
```
cf curl /v3/apps/:guid?include=space
```

Read more about [the `include` parameter](#include).

## New Concepts

### Actions

Actions are API requests that are expected to immediately initiate change within the Cloud Foundry runtime. This is differentiated from requests which update a record but require additional updates, such as restarting an app, to cause changes to a resource to take effect.

Example:
```
POST /v3/apps/:guid/actions/start
```

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="links-v3">Links</h3>

```
Example Request
```

```shell
curl "https://api.example.org/v3/apps/:guid" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```json
{
  "...": "...",
  "links": {
    "self": {
      "href": "http://api.example.com/v3/apps/:guid"
    },
    "space": {
      "href": "http://api.example.com/v3/spaces/:space_guid"
    }
  }
}
```

Links provide URLs to associated resources, relationships, and actions for a resource.
The example links to both the app itself and the space in which it resides.

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="metadata-v3">Metadata</h3>

```
Example Request
```

```shell
curl "https://api.example.org/v3/:resource/:guid" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```json
{
  "...": "...",
  "metadata": {
    "labels": {
      "environment": "production",
      "internet-facing": "false"
    },
    "annotations": {
      "contacts": "Bill tel(1111111) email(bill@fixme)"
    }
  }
}
```

Metadata allows you to tag and query certain API resources with information; metadata does not affect the resource's functionality.

For more details and usage examples, see [metadata](#metadata) or [official CF docs](https://docs.cloudfoundry.org/adminguide/metadata.html).

Note that metadata consists of two keys, `labels` and `annotations`, each of which consists of key-value pairs. API V3 allows filtering by labels (see [label_selector](#labels-and-selectors)) but not by annotations.

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="relationships-v3">Relationships</h3>


```
Example Request
```

```shell
curl "https://api.example.org/v3/apps" \
  -X POST \
  -H "Authorization: bearer [token]"
  -d '{
        "name": "testapp",
        "relationships": {
         "space": { "data": { "guid": "1234" }}
        }
      }'
```

Relationships represent associations between resources: For example, every space belongs in an organization, and every app belongs in a space. The V3 API can create, read, update, and delete these associations.

In the example request we create an app with a relationship to a specific space.

One can retrieve or update a resource's relationships. For example, to retrieve an app's relationship to its space with the `/v3/apps/:app_guid/relationships/space` endpoint.

For more information, refer to the [relationships](#relationships).

## New Resources

The V3 API introduces new resources that are not available on the V2 API. Below are brief descriptions of these resources. This is not intended to be an exhaustive list and may not be updated as new resources are added to V3.

**Note:** Some of these resources may still be experimental and are subject to change or removal without warning. For up to date information on which resources are still experimental see [Experimental Resources](#experimental-resources).

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="app-features-v3">App Features</h3>

App features support enabling/disabling behaviors for an individual app.

Read more about the [app feature resource](#app-features).

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="deployments-v3">Deployments</h3>

Deployments are objects that manage updates to applications with zero downtime.

Read more about the [deployment resource](#deployments).

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="isolation-segments-v3">Isolation Segments</h3>

Isolation segments provide dedicated pools of resources to which apps can be deployed to isolate workloads.

Read more about the [isolation segment resource](#isolation-segments).

### Manifests

Manifests are a method for providing bulk configuration to applications and other resources in a space.

Read more about the [app manifest](#app-manifest) and [space manifest](#space-manifest) resources.

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="revisions-v3">Revisions</h3>

Revisions represent code and configuration used by an application at a specific time. The most recent revision for a running application represents the code and configuration currently running in Cloud Foundry.

Read more about the [revision resource](#revisions).

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="sidecars-v3">Sidecars</h3>

Sidecars are additional programs that are run in the same container as a process.

Read more about the [sidecar resource](#sidecars).

<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="tasks-v3">Tasks</h3>

Tasks are one-off jobs that are intended to execute a droplet, stop, and be cleaned up, freeing up resources.

Examples of this include database migrations and running batch jobs.

Read more about the [task resource](#tasks).

## Useful Links

1. [V3 API Proposals](https://docs.google.com/document/d/1g48YPBfwXT8kNrJYroBNkhlCtROe53INEEzvhQaAUOI)
2. [CAPI (Cloud Controller API) Slack Channel](https://cloudfoundry.slack.com/messages/C07C04W4Q)
