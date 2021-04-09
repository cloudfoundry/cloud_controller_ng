*This file has been relocated from a [separate repo](https://github.com/cloudfoundry/cc-api-v3-style-guide), which has been archived for historical context*

# Cloud Controller API v3 Style Guide

## Table of Contents
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
  - [Guiding Principles](#guiding-principles)
  - [API Technologies](#api-technologies)
  - [API Design Inspirations](#api-design-inspirations)
  - [Overview Example](#overview-example)
- [Requests](#requests)
  - [URL Structure](#url-structure)
  - [GET](#get)
    - [Examples](#examples)
      - [Show Individual Resource](#show-individual-resource)
      - [List Collection of Resources](#list-collection-of-resources)
    - [Responses](#responses)
      - [Show Resource](#show-resource)
      - [List Collection](#list-collection)
  - [POST](#post)
    - [Examples](#examples-1)
      - [Create a Resource](#create-a-resource)
      - [Trigger an Action](#trigger-an-action)
    - [Responses](#responses-1)
      - [Create Resource](#create-resource)
      - [Trigger Action](#trigger-action)
  - [PUT](#put)
  - [PATCH](#patch)
    - [Examples](#examples-2)
      - [Partially Update a Resource](#partially-update-a-resource)
    - [Responses](#responses-2)
      - [Update a Resource](#update-a-resource)
  - [DELETE](#delete)
    - [Examples](#examples-3)
      - [Delete a Resource](#delete-a-resource)
    - [Responses](#responses-3)
      - [Delete Resource](#delete-resource)
- [Response Codes](#response-codes)
  - [Successful Requests](#successful-requests)
  - [Redirection](#redirection)
  - [Client Errors](#client-errors)
    - [404 vs 403](#404-vs-403)
  - [Server Errors](#server-errors)
- [Resources](#resources)
  - [Example](#example)
- [Pseudo-Resources](#pseudo-resources)
  - [Example](#example-1)
- [Actions](#actions)
  - [Example](#example-2)
- [Field Names](#field-names)
    - [Example](#example-3)
- [Links](#links)
  - [Example](#example-4)
- [Collections](#collections)
  - [Example](#example-5)
- [Pagination](#pagination)
  - [Example](#example-6)
- [Query Parameters](#query-parameters)
    - [Examples](#examples-4)
- [Filtering](#filtering)
    - [Examples](#examples-5)
  - [Filtering on Inequalities (Proposal)](#filtering-on-inequalities-proposal)
  - [Filtering on Non-Equality (Proposal)](#filtering-on-non-equality-proposal)
- [Errors](#errors)
  - [Status Codes](#status-codes)
  - [Response Body](#response-body)
    - [Example](#example-7)
  - [Error Messages](#error-messages)
- [Relationships](#relationships)
  - [Relationships at Resource Creation](#relationships-at-resource-creation)
    - [To-One Relationships](#to-one-relationships)
    - [To-Many Relationships](#to-many-relationships)
  - [Relationships for Existing Resources](#relationships-for-existing-resources)
    - [To-One Relationships](#to-one-relationships-1)
      - [Viewing](#viewing)
      - [Setting](#setting)
      - [Clearing](#clearing)
    - [To-Many Relationships](#to-many-relationships-1)
      - [Viewing](#viewing-1)
      - [Adding](#adding)
      - [Removing](#removing)
      - [Replacing All](#replacing-all)
      - [Clearing All](#clearing-all)
- [Nested Resources](#nested-resources)
- [Including Related Resources](#including-related-resources)
  - [Pagination of Included Resources (Proposal)](#pagination-of-included-resources-proposal)
    - [Pagination Links](#pagination-links)
- [GUID Hiding](#guid-hiding)
- [Asynchronicity](#asynchronicity)
  - [Triggering Async Actions](#triggering-async-actions)
  - [Monitoring Async Actions](#monitoring-async-actions)
  - [Viewing Errors from Async Actions](#viewing-errors-from-async-actions)
  - [Viewing Warnings from Async Actions](#viewing-warnings-from-async-actions)
- [Requesting Specific Fields Resources (Proposal)](#requesting-specific-fields-resources-proposal)
  - [Sparse Fields](#sparse-fields)
  - [Hidden Fields](#hidden-fields)
  - [Proposal: Fields For Sub-Resources](#proposal-fields-for-sub-resources)
- [Proposal: Mass Deletes](#proposal-mass-deletes)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Overview

This document serves as a style guide for version 3 of the Cloud Controller API. It is intended to act as a repository for patterns and best practices when designing and developing new API endpoints.

This is a living document; It will change over time as we learn more about our users and develop features.

### Guiding Principles

* **Consistency**: Understanding how to interact with one resource informs how to interact with any resource.
* **Discoverability**: API responses guide users without the need for external documentation.
* **Simplicity**: Complex user workflows are constructed from smaller, easier to understand parts.
* **Opinionatedness**: There is one clear way to do something.

### API Technologies
* **HTTP:** All API requests **MUST** be made over HTTP.
* **JSON:** Most API request and response bodies will be JSON objects.
* **YAML:** Some API requests and response bodies will be YAML objects.
* **Multipart Form Data:** API request bodies requiring file uploads will be multipart form data.

### API Design Inspirations
* **REST:**  https://en.wikipedia.org/wiki/Representational_state_transfer
* **JSON API:** http://jsonapi.org/
* **HAL:** http://stateless.co/hal_specification.html

### Overview Example
Here is an example request to retrieve apps:

```
GET /v3/apps?names=dora,kailan&order_by=created_at&page=1&per_page=2
```

> **Note:** To make the examples in this style guide more human-readable, the urls in this style guide to not encode query strings.  All requests and responses **MUST** contain correctly encoded characters. For more information see [Query Parameters](#query-parameters).

Here is the respective response body:

```json
{
  "pagination": {
    "total_results": 3,
    "total_pages": 2,
    "first": {
      "href": "http://api.example.com/v3/apps?names=dora,kailan&order_by=created_at&page=1&per_page=2"
    },
    "last": {
      "href": "http://api.example.com/v3/apps?names=dora,kailan&order_by=created_at&page=2&per_page=2"
    },
    "next": {
      "href": "http://api.example.com/v3/apps?names=dora,kailan&order_by=created_at&page=2&per_page=2"
    },
    "previous": null
  },
  "resources": [
    {
      "guid": "guid-00133700-abcd-1234-9000-3f70a011bc28",
      "name": "dora",
      "state": "STOPPED",
      "created_at": "2015-08-06T00:36:20Z",
      "updated_at": "2015-08-06T00:36:20Z",
      "links": {
        "self": {
          "href": "https://api.example.org/v3/apps/guid-00133700-abcd-1234-9000-3f70a011bc28"
        },
        "space": {
          "href": "https://api.example.org/v3/spaces/ab09cd29-9420-f021-g20d-123431420768"
        },
        "processes": {
          "href": "https://api.example.org/v3/apps/guid-00133700-abcd-1234-9000-3f70a011bc28/processes"
        },
        "routes": {
          "href": "https://api.example.org/v3/apps/guid-00133700-abcd-1234-9000-3f70a011bc28/routes"
        },
        "packages": {
          "href": "https://api.example.org/v3/apps/guid-00133700-abcd-1234-9000-3f70a011bc28/packages"
        },
        "droplets": {
          "href": "https://api.example.org/v3/apps/guid-00133700-abcd-1234-9000-3f70a011bc28/droplets"
        },
        "start": {
          "href": "https://api.example.org/v3/apps/guid-00133700-abcd-1234-9000-3f70a011bc28/start",
          "method": "POST"
        },
        "stop": {
          "href": "https://api.example.org/v3/apps/guid-00133700-abcd-1234-9000-3f70a011bc28/stop",
          "method": "POST"
        }
      }
    },
    {
      "guid": "guid-bd7369a8-deed-ff1a-2315-77410293a922",
      "name": "kailan",
      "state": "STOPPED",
      "created_at": "2015-08-07T00:40:52Z",
      "updated_at": "2015-08-07T00:40:52Z",
      "links": {
        "self": {
          "href": "https://api.example.org/v3/apps/guid-bd7369a8-deed-ff1a-2315-77410293a922"
        },
        "space": {
          "href": "https://api.example.org/v3/spaces/881029ab-4edd-4920-af10-6386967209d1"
        },
        "processes": {
          "href": "https://api.example.org/v3/apps/guid-bd7369a8-deed-ff1a-2315-77410293a922/processes"
        },
        "routes": {
          "href": "https://api.example.org/v3/apps/guid-bd7369a8-deed-ff1a-2315-77410293a922/routes"
        },
        "packages": {
          "href": "https://api.example.org/v3/apps/guid-bd7369a8-deed-ff1a-2315-77410293a922/packages"
        },
        "droplets": {
          "href": "https://api.example.org/v3/apps/guid-bd7369a8-deed-ff1a-2315-77410293a922/droplets"
        },
        "start": {
          "href": "https://api.example.org/v3/apps/guid-bd7369a8-deed-ff1a-2315-77410293a922/start",
          "method": "POST"
        },
        "stop": {
          "href": "https://api.example.org/v3/apps/guid-bd7369a8-deed-ff1a-2315-77410293a922/stop",
          "method": "POST"
        }
      }
    }
  ]
}
```

## Requests

### URL Structure

All endpoints **MUST** be prefixed with `/v3/`.

Collections of resources are referenced by their resource name (plural)  
Pattern: `/v3/:resource_name`  
Example: `/v3/apps`  

Individual resources are referenced by their resource name (plural) followed by the resource's guid  
Pattern: `/v3/:resource_name/:guid`  
Example:  `/v3/apps/25fe21b8-8de2-40d0-93b0-c819101d1a11`  

### GET
Retrieve a single resource or a list of resources. **MUST** be idempotent.

* GET requests **MAY** include query parameters
* GET requests **MUST NOT** include a request body

#### Examples

##### Show Individual Resource

```
GET /v3/apps/:guid
```

##### List Collection of Resources

```
GET /v3/apps
```

#### Responses

##### Show Resource
|Scenario|Code|Body|
|---|---|---|
| Authorized User | 200 | Resource |
| Unauthorized User | 404 | Error |
| Nonexistent Resource | 404 | Error |

##### List Collection

|Scenario|Code|Body|
|---|---|---|
| User With Complete Visibility | 200 | List of All Resources |
| User With Partial Visibility | 200 | List of Visible Resources |
| User With No Visibility | 200 | Empty List |

### POST
Used to create a resource, upload a file, or trigger an [action](#actions).

* POST requests **MUST NOT** include query parameters
* POST requests **MAY** include a request body

#### Examples

##### Create a Resource

```
POST /v3/apps
```
```json
{
  "name": "example_app"
}
```

##### Trigger an Action

```
POST /v3/processes/:guid/actions/scale
```
```json
{
  "instances": 100,
  "memory_in_mb": 2048
}
```

#### Responses

##### Create Resource

| Scenario                                          | Code | Body                            |
| ------------------------------------------------- | ---- | ------------------------------- |
| Authorized User (Synchronous)                     | 201  | Created Resource                |
| Authorized User [(Asynchronous)](#asynchronicity) | 202  | Empty w/ Location Header -> Job |
| Unauthorized User                                 | 403  | Error                           |

##### Trigger Action

|Scenario|Code|Body|
|---|---|---|
| Authorized User (Synchronous) | 200 | Resource |
| Authorized User [(Asynchronous)](#asynchronicity) | 202 | Empty w/ Location Header -> Job |
| Read-Only User | 403 | Error |
| Unauthorized User | 404 | Error |
| Nonexistent Resource | 404 | Error |

### PUT
Not used. To update a resource, use [PATCH](#patch)

### PATCH
Used to update a portion of a resource.

* PATCH requests **MUST NOT** include query parameters
* PATCH requests **MAY** include a request body
* PATCH operations **MUST** apply all requested updates or none.

#### Examples
##### Partially Update a Resource

```
PATCH /v3/apps/:guid
```
```json
{
  "name": "new_app_name"
}
```

#### Responses

##### Update a Resource

|Scenario|Code|Body|
|---|---|---|
| Authorized User (Synchronous) | 200 | Updated Resource |
| Authorized User [(Asynchronous)](#asynchronicity) | 202 | Empty w/ Location Header -> Job |
| Read-Only User | 403 | Error |
| Unauthorized User | 404 | Error |
| Nonexistent Resource | 404 | Error |

### DELETE
Used to delete a resource.

* DELETE requests **MAY** include query parameters
* DELETE requests **MUST NOT** include a request body †
* Deleting a resource **MAY** also recursively delete associated resources.
* Deleting a resource **MAY** occur syncronously or [asyncronously](#asynchronicity)

> † Some load balancers remove bodies from DELETE requests. Since the API could be running behind any load balancer, we cannot depend on DELETE requests with bodies.

#### Examples
##### Delete a Resource

```
DELETE /v3/apps/:guid
```

#### Responses

##### Delete Resource

|Scenario|Code|Body|
|---|---|---|
| Authorized User [(Asynchronous)](#asynchronicity) | 202 | Empty w/ Location Header -> Job |
| Authorized User (Synchronous) | 204 | Empty |
| Read-only User | 403 | Error |
| Unauthorized User | 404 | Error |
| Nonexistent Resource | 404 | Error |

## Response Codes

### Successful Requests

|Status Code|Description|Verbs|
|---|---|---|
|200 OK|This status **MUST** be returned for synchronous requests that complete successfully and have a response body. This **MUST** only be used if there is not a more appropriate 2XX response code. |GET, PATCH, POST (for actions)|
|201 Created|This status **MUST** be returned for synchronous requests that result in the creation of a new resource.|POST|
|202 Accepted|This status **MUST** be returned for requests that have been successfully accepted and will be asynchronously completed at a later time. See more in the [async](#asynchronicity) section. |POST, PATCH, DELETE|
|204 No Content|This status **MUST** be returned for synchronous requests that complete successfully and have no response body. |DELETE |


### Redirection

|Status Code|Description|Verbs|
|---|---|---|
|302 Found| This status **MUST** be returned when the cloud controller redirects to another location. Example: Downloading a package from an external blob store.  |GET|


### Client Errors

|Status Code|Description|Verbs|
|---|---|---|
|400 Bad Request|This status **MUST** be returned for requests that provide malformed or invalid data. Examples: malformed request body, unexpected query parameters, or invalid request fields.|GET, PATCH, POST, DELETE|
|401 Unauthenticated|This status **MUST** be returned if the requested resource requires an authenticated user but there is no OAuth token provided, or the OAuth token provided is invalid.|GET, POST, PATCH, DELETE|
|403 Forbidden|This status **MUST** be returned if the request cannot be performed by the user due to lack of permissions. Example: User with read-only permissions to a resource tries to update it. |POST, PATCH, DELETE|
|404 Not Found|This status **MUST** be returned if the requested resource does not exist or if the user requesting the resource has insufficient permissions to view the resource.|GET, POST, PATCH, DELETE|
|422 Unprocessable Entity|This status **MUST** be returned if the request is syntactically valid, but performing the requested operation would result in a invalid state. Example: Attempting to start an app without assigning a droplet.|POST, PATCH, DELETE|

#### 404 vs 403

If a resource does not exist OR a user does not have read permissions for it, then 404 **MUST** be returned for PATCH/DELETE requests. This is to prevent leaking information about what resources exist by returning 403s for resources that exist, but a user does not have read permissions for. Explicitly:

||**No Permissions**|**Read-Only Permissions**|**Read/Write Permissions**|
|-|-|-|-|
|**Resource Exists**| 404 | 403 | 2XX |
|**Resource Does Not Exist**| 404 | 404 | 404 |

### Server Errors

| Status Code | Description |
| ----------- | ----------- |
|500 Internal Server Error|This status **MUST** be returned when an unexpected error occurs. |
|502 Bad Gateway|This status **MUST** be returned when an external service failure causes a request to fail. Example: Being unable to reach requested service broker. |
|503 Service Unavailable|This status **MUST** be returned when an internal service failure causes a request to fail. Example: Being unable to reach Diego or CredHub. |

## Resources

A resource represents an individual object within the system, such as an app or a service.  It is represented as a JSON object.  

A resource **MUST** contain the following fields:

* `guid`: a [universally unique identifier](https://www.itu.int/en/ITU-T/asn1/Pages/UUID/uuids.aspx) for the resource
* `created_at`: an ISO8601 compatible date and time that the resource was created
* `updated_at`: an ISO8601 compatible date and time that the resource was last updated

A resource **MAY** contain additional fields which are the attributes describing the resource.

A resource **MUST** contain a `links` field containing a [links](#links) object, which is used to provide URLs to associated resources, relationships, and actions for the resource.

A resource **MUST** include a `self` link object in the `links` field.

### Example

```json
{
  "guid": "00112233-4455-6677-8899-aabbccddeeff",
  "created_at": "2015-07-06T23:22:56Z",
  "updated_at": "2015-07-08T23:22:56Z",

  "name": "dora",
  "description": "an example app",

  "links": {
    "self": {
      "href": "http://api.example.com/v3/apps/00112233-4455-6677-8899-aabbccddeeff"
    }
  }
}
```

## Pseudo-Resources

Pseudo-Resources are API endpoints that are nested under other resources and do not have a unique identifier. Their lifecycles are tied directly to their parent resource. These endpoints **MAY** require different permissions to operate on than their parent resource.

### Example

`GET /v3/apps/:guid/environment_variables`


## Actions

Actions are API requests that are expected to initiate change within the Cloud Foundry runtime.  This is differentiated from requests which update a record, but require additional updates — such as restarting an app — to cause changes to a resource to take affect.  

Actions **MUST** use use POST as their HTTP verb.

Actions **MUST** be nested under the `/actions` path for a resource

Actions **MAY** accept a request body.

Actions **MUST** be listed in the `links` for the related resource.

### Example
 `POST /v3/apps/:guid/actions/start`


## Field Names

Resource Fields **MUST** include **ONLY** the following characters:

* a-z (lowercase only)
* _ (underscore)

Resource fields that accept multiple values **MUST** be pluralized.

#### Example
```json

{
  "guid": "guid-1",
  "color": "red",
  "animals": [
    "fish",
    "lion"
  ]
}
```

## Links

Links provide URLs to associated resources, relationships, and actions for a resource.  Links are represented as a JSON object.

Each member of a links object is a "link".  
A link **MUST** be a JSON object.
A link **MUST** contain a `href` field, which is a string containing the link's relative URL.
A link **MAY** contain a `method` field, containing the HTTP verb used for the URL.  If the `method` field is not included then the link **MUST** be available using GET.

### Example

```json
{
  "links": {
    "self": {
      "href": "http://api.example.com/v3/apps/00112233-4455-6677-8899-aabbccddeeff"
    },
    "space": {
      "href": "http://api.example.com/v3/spaces/123e4567-e89b-12d3-a456-426655440000"
    },
    "current_droplet": {
      "href": "http://api.example.com/v3/apps/00112233-4455-6677-8899-aabbccddeeff/relationships/current_droplet"
    },
    "start": {
      "href": "http://api.example.com/v3/apps/00112233-4455-6677-8899-aabbccddeeff/start",
      "method": "PUT"
    }
  }
}
```

## Collections
A collection is a list of multiple Resources.  A collection is represented as a JSON object.

A collection **MUST** contain a `resources` field.  The resources field is an array containing multiple [Resources](#resources).

A collection **MUST** contain a `pagination` field containing a [pagination](#pagination) object.

### Example

```json
{
  "pagination": {
    "total_results": 2,
    "total_pages": 1,
    "first": {
      "href": "http://api.example.com/v3/apps?page=1&per_page=10"
    },
    "last": {
      "href": "http://api.example.com/v3/apps?page=1&per_page=10"
    },
    "next": null,
    "previous": null
  },
  "resources": [
    {
      "guid": "a-b-c",
      "created_at": "2015-07-06T23:22:56Z",
      "updated_at": "2015-07-08T23:22:56Z",

      "links": {
        "self": {
          "href": "http://api.example.com/v3/apps/a-b-c"
        }
      }
    },
    {
      "guid": "d-e-f",
      "created_at": "2015-07-06T23:22:56Z",
      "updated_at": "2015-07-08T23:22:56Z",

      "links": {
        "self": {
          "href": "http://api.example.com/v3/apps/d-e-f"
        }
      }
    }
  ]
}
```

## Pagination

Pagination **MAY** be used by [Collections](#collections) to limit the number of resources returned at a time.  Pagination is requested by a client through the use of query parameters. Pagination is represented as a JSON object.

Pagination **MUST** include a `total_results` field with an integer value of the total number of records in the collection.

Pagination **MUST** include a `total_pages` field with an integer value of the total number of pages in the collection at the current page size.

Pagination **MUST** include the following fields for pagination links:

* `first`: URL for the first page of resources
* `last`: URL for the last page of resources
* `previous`: URL for the previous page of resources
* `next`: URL for the next page of resources

Pagination links **MAY** be `null`.  For example, if the page currently being displayed is the first page, then  `previous` link will be null.

When pagination links contain a URL, they **MUST** be a JSON object with a field named `href` containing a string with the URL for the next page.

The following query parameters **MUST** be supported for pagination:

* `page`: the page number of resources to return (default: 1)
* `per_page`: the number of resources to return in a paginated collection request (default: 50)
* `order_by`: a field on the resource to order the collection by; each collection will have a different subset of fields that can be sorted by 

When collections are ordered by a subset of fields, each field **MAY** be prepended with "-" to indicate descending order direction. If the field is not prepended, the ordering will default to ascending.

If there are additional pagination query parameters, the parameters **MUST** have names that conform to the acceptable [query parameter](#query-parameters) names.

Pagination URLs **MUST** include _all_ query parameters required to maintain consistency with the original pagination request.  For example, if the client requested for the collection to be sorted by a certain field, then the pagination links **MUST** include the proper query parameter to maintain the requested sort order.

### Example

```json
{
  "pagination": {
    "total_results": 20,
    "total_pages": 2,
    "first": {
      "href": "http://api.example.com/v3/apps?order_by=-created_at&page=1&per_page=10"
    },
    "last": {
      "href": "http://api.example.com/v3/apps?order_by=-created_at&page=2&per_page=10"
    },
    "next": {
      "href": "http://api.example.com/v3/apps?order_by=-created_at&page=2&per_page=10"
    },
    "previous": null
  }
}
```

## Query Parameters

Query Parameters **MUST** include **ONLY** the following characters:

* a-z (lowercase only)
* _ (underscore)

Query parameters that accept multiple values **MUST** be pluralized.

If any request receives a query parameter it does not understand, the response **MUST** be a `400 Bad Request`.

All query parameters **MUST** be properly [url-encoded](https://en.wikipedia.org/wiki/Percent-encoding#Current_standard). If a single query parameter value includes the comma (`,`) character, the comma **MUST** be double encoded. 

> **Note:** For readability purposes, the examples throughout this document do not show encoded query strings.

#### Examples
Single value:
`GET /v3/apps?names=firstname`

Multiple values:
 `GET /v3/apps?names=firstname,secondname`

Single value with comma:
 `GET /v3/apps?names=comma%2Cname`


## Filtering

Filtering is the use of query parameters to return a subset of resources within
a [Collection](#collections).

Filter query parameters **MUST** have names that conform to the acceptable
[query parameter](#query-parameters) names.

Filters **MUST** allow a client to request resources matching multiple values by
accepting a comma-delimited list of possible values.

Filter parameters **MUST** be able to be combined with other filters on the same
collection.

When multiple filters are provided, the results **MUST** match all specified
filters.

Empty filters (`/v3/apps?names=` or `/v3/buildpacks?stack=cflinuxfs2,`) matches
on [Active Support's definition of
blank](https://guides.rubyonrails.org/active_support_core_extensions.html#blank-questionmark-and-present-questionmark)
meaning that `nil`, `""` and `[]` will be valid matches for the empty filter.

#### Examples

**Single value request**:
`GET /v3/apps?names=the_name`

This will return all apps with name `the_name`.

**Multiple value request**:
`GET /v3/apps?names=first_name,second_name`

This will return all apps with name `the_name` OR `second_name`.

**Combined filters**:
`GET /v3/apps?names=the_name&state=STARTED`

This will return all apps with name `the_name` AND state `STARTED`.

**Empty filters when resource has `NULLs`**:
`GET /v3/buildpacks?stack=`

This will return all buildpacks with stack `NULL`.

**Empty filters when resource has empty strings (`""`)**:
`GET /v3/routes?path=pepper,,tabi`

This will return all routes with path `"pepper"`, `""` OR `"tabi"`.

### Filtering on Inequalities (Proposal)

> Note: This is a proposal and is not currently implemented on any API endpoints

Resources **MAY** support filtering on inequalities for some fields.

**Strictly Less Than**:
`GET /v3/processes?instances[lt]=5`

This will return all processes with less than 5 instances.

**Less Than or Equal To**:
`GET /v3/processes?instances[lte]=5`

This will return all processes with less than 5 instances or exactly 5 instances.

**Strictly Greater Than**:
`GET /v3/processes?instances[gt]=5`

This will return all processes with greater than 5 instances.

**Greater Than or Equal To**:
`GET /v3/processes?instances[gte]=5`

This will return all processes with greater than 5 instances or exactly 5 instances.

### Filtering on Non-Equality (Proposal)

> Note: This is a proposal and is not currently implemented on any API endpoints

Resources **MAY** support filtering on inequalities for some fields.

`GET /v3/apps?names[not]=my-app`

This will return all apps with names other than `my-app`.

## Errors

### Status Codes

The HTTP status code returned for errors **MUST** be included in the documented [status codes](#response-codes).

### Response Body

The response body **MUST** return a JSON object including an `errors` key with a list of at least one error objects. 

Each error object in the list **MUST** include the following keys:
* **detail**: User-readable message describing the error. Intended to be surfaced by clients to users.
* **title**: Human-readable unique descriptor for the class of error. Intended to help troubleshooting.
* **code**:  Numerical, unique identifier for the class of error. Intended to help troubleshooting.

#### Example

```json
{
  "errors": [
    {
       "detail": "Relationships is not a hash.",
       "title": "CF-UnprocessableEntity",
       "code": 10008
    },
    {
       "detail": "Name must be a string.",
       "title": "CF-UnprocessableEntity",
       "code": 10008
    }
  ]
}
```

### Error Messages

Error messages should be descriptive and gramatically correct, so they can be surfaced by API clients without need for modification.

Each error message **MUST**:
- Start with a capital letter
- Be one or more complete English sentences
- Conclude with a full stop (`.`) 

## Relationships

Relationships represent named associations between resources. Relationships can be used to create, read, update, and delete associations through the relationship sub resource.

A resource **MAY** have a relationship with exactly one instance of a resource (a _to-one_ relationship).

A resource **MAY** have a relationship with multiple instances of a resource (a _to-many_ relationship).

Resources **MAY** implement none, some, or all of the relationship operation listed below for each of its associations.

### Relationships at Resource Creation

#### To-One Relationships

Create an association between the resource being created and a single, existing resource.

Example:
```
POST /v3/apps
```
```json
{
  "name": "blah",
  "relationships": {
   "space": { "data": { "guid": "1234" }}
  }
}
```

#### To-Many Relationships

Create associations between the resource being created and several existing resources.

Example:
```
POST /v3/apps
```
```json
{
  "name": "blah",
  "relationships": {
    "routes": {
      "data": [
        {"guid": "2345"},
        {"guid": "3456"}
      ]
    }
  }
}
```

### Relationships for Existing Resources

Viewing, updating, and removing relationships for existing resources can be accessed through nested relationship resource endpoints.

#### To-One Relationships

##### Viewing
View the association between a resource and a single other resource for the given relationship.

Example:
```json
GET /v3/apps/:app_guid/relationships/space
```
Response:
```json
{
  "data": { "guid": "space-guid" }
}
```

##### Setting
Update the association for a resource to a single other resource for the given relationship.

Example:
```json
PATCH /v3/apps/:app_guid/relationships/space
{
  "data": { "guid": "space-guid" }
}
```

##### Clearing
Remove the association between two resources for the given relationship.

Example:
```json
PATCH /v3/apps/:app_guid/relationships/space
{
  "data": null
}
```

#### To-Many Relationships

##### Viewing
View the associations between a resource and multiple other resources for the given relationship.

Example:
```json
GET /v3/apps/:app_guid/relationships/routes
```
Response:
```json
{
  "data": [
    { "guid": "route-guid" },
    { "guid": "other-route-guid" }
  ]
}
```

##### Adding

Add additional associations between a resource and other resources for the given relationship.

Example:
```json
POST /v3/apps/:app_guid/relationships/routes
{
  "data": [{ "guid": "route-guid" }, { "guid": "route-guid" }]
}
```

##### Removing

Remove the association between a resource and another resource for the given relationship.

```json
DELETE /v3/apps/:app_guid/relationships/routes/:route_guid
```

> Note: Some load balancers remove request bodies from DELETE requests. Because of this, we cannot support atomically removing more than one resource in a single request.

##### Replacing All

Replace all associations between a resource and other resources for the given relationship.

```json
PATCH /v3/apps/:app_guid/relationships/routes
{
  "data": [{ "guid": "route-guid" }, { "guid": "other-route-guid" }]
}
```

##### Clearing All

Clear all associations between a resource and other resources for the given relationship.

```json
PATCH /v3/apps/:app_guid/relationships/routes
{
  "data": []
}
```

## Nested Resources

Nested resources **MAY** be accessible through their parent resource.
```
GET /v3/apps/:app_guid/droplets
```
This will be equivalent to
```
GET /v3/droplets?app_guids=:app_guid
```

## Including Related Resources

This is a mechanism for including multiple related resources in a single response.

Resources and collections **MAY** accept an `include` query parameter with a list of resource paths.

Each resource path **MUST** be a series of period-separated relationship names. For example: `app.space.organization`

The list of resource paths **MUST** be comma delimited. For example: `include=space,space.organization`

Included resources **MUST** be returned in an `included` object on the primary resource or collection.  

Duplicate included resources **MUST NOT** be repeated. For example: Listing multiple apps in the same space with `include=space` will only return the space once.

```
GET /v3/apps?include=space,space.organization
```
```json
{
  "pagination": {
    "total_results": 2,
    "total_pages": 1,
    "first": {
      "href": "http://api.example.com/v3/apps?include=space,space.organization&page=1"
    },
    "last": {
      "href": "http://api.example.com/v3/apps?include=space,space.organization&page=1"
    },
    "next": null,
    "previous": null
  },
  "resources": [
    {
      "guid": "app1-guid",
      "relationships": {
        "space": {"guid": "space2-guid"}
      }
    },
    {
      "guid": "app2-guid",
      "relationships": {
        "space": {"guid": "space1-guid"}
      }
    }
  ],
  "included": {
    "spaces": [
      {
        "guid": "space1-guid",
        "relationships": {
          "organization": {"guid": "org1-guid"}
        }
      },
      {
        "guid": "space2-guid",
        "relationships": {
          "organization": {"guid": "org1-guid"}
        }
      }
    ],
    "organizations": [
      {
        "guid": "org1-guid"
      }
    ]
  }
}
```
### Pagination of Included Resources (Proposal)

> Note: This is a proposal and is not currently implemented on any API endpoints

When including to-many relationships, there can be more related resources than can be returned in a single response. In that case, only the first page of the included resources will be returned.

```
GET /v3/spaces/:guid?include=apps
```

```json
{
  "guid": "space-guid",
  "...": "...",
  "relationships": {
    "apps": {
      "data": [
        {"guid": "app-guid-1"},
        "...",
        {"guid": "app-guid-100"}
      ]
    }
  },
  "included": {
    "apps": {
      "resources": [
        {"guid": "app-guid-1"},
        "...",
        {"guid": "app-guid-10"}
      ]
    }
  }
}
```

The included resources are paginated using pagination filters for each included resource:

```
GET /v3/spaces/:guid?include=apps&page[apps]=10
```
```json
{
  "guid": "space-guid",
  "...": "...",
  "relationships": {
    "apps": {
      "data": [
        {"guid": "app-guid-1"},
        "...",
        {"guid": "app-guid-100"}
      ]
    }
  },
  "included": {
    "apps": {
      "resources": [
        {"guid": "app-guid-90"},
        "...",
        {"guid": "app-guid-100"}
      ]
    }
  }
}
```

#### Pagination Links

The pagination filters for included resources are included in the top-level pagination links. The `next` pagination links will page through all included resources before moving to the next page of the root resource.

```json
{
  "pagination": {
    "...": "...",
    "first": {
      "href": "https://api.example.com/v3/spaces?include=apps&page=1&page[apps]=1"
    },
    "last": {
      "href": "https://api.example.com/v3/spaces?include=apps&page=10&page[apps]=10"
    },
    "next": {
      "href": "https://api.example.com/v3/spaces?include=apps&page=1&page[apps]=2"
    },
    "previous": null
  }
}
```



## GUID Hiding

Resources that are visible to any given user can have relationships/links with other resources that that user does not have read access for.

In these cases, the following rules apply:
1. If the resource is scoped to a particular organization/space and is shared to a different organization/space, then the owning organization/space guid will be visible.
1. In all other cases, users will not be able to see the guids of resources that they otherwise do not have read access for.

## Asynchronicity

Individual endpoints are responsible for behaving either asynchronously (return 202 status code) or synchronously (return non-202 status code).

Since Cloud Controller collaborates with multiple external Cloud Foundry components, many endpoints will have asynchronous side effects that do not necessarily need to be represented by an async job on the API. For example, scaling the number of instances of a process will trigger their asynchronous creation in the runtime. However, the user's action was to increment the instance count in the CC's data store, which is not an asynchronous operation. The CC then works behind the scenes to make the system consistent by creating the LRPs (much as it would if the runtime lost state and CC needed to recover the desired state).

In general, good signs an endpoint should return an async job are:
1. Updating state in the CC will take significant time/processing. Example: recursive deletes
2. Updating state in the CC requires talking to the blobstore. Example: file uploads

Keep in mind that only the user/client that issued the request triggering the async job will have the link to track the job. If other users or system components care about the operation, it is helpful to surface state elsewhere -- either on the resource itself or through the creation of another resource.


### Triggering Async Actions

The CC will return a 202 with a `Location` header pointing to the async job.
```
DELETE /v3/resource/:guid
202 Accepted
Location: /v3/jobs/123
```
### Monitoring Async Actions

GET requests made to the job resource **MUST** return 200 with information about the status of the job.

```
GET /v3/jobs/123
200 OK
```
```json
{
  "state": "PROCESSING",
  "operation": "service_instance.create",
  "status": "Warming the shards",
  "warnings": [],
  "links": {
    "self": {
      "href": "https://api.example.org/v3/jobs/123"
    }
  }
}
```

The job resource **MAY** include links to resources affected by the operation.

```
GET /v3/jobs/123
200 OK
```
```json
{
  "state": "COMPLETE",
  "operation": "splines.reticulate",
  "status": "Splines successfully reticulated",
  "warnings": [],
  "links": {
    "self": {
      "href": "https://api.example.org/v3/jobs/123"
    },
    "splines": {
      "href": "https://api.example.org/v3/splines/456"
    }
  }
}
```

### Viewing Errors from Async Actions

The job resource **MUST** surface any errors that occur during the async operation.

```json
GET /v3/jobs/123
200 OK

{
  "state": "FAILED",
  "operation": "sun.fly_to",
  "status": "Failed to fly to the sun",
  "errors": [
      {
       "detail": "Wings are too waxy.",
       "title": "CF-UnprocessableEntity",
       "code": 10008
    },
    {
       "detail": "Hubris is too high.",
       "title": "CF-UnprocessableEntity",
       "code": 10008
    }
  ],
  "warnings": [],
  "links": {
    "self": {
      "href": "https://api.example.org/v3/jobs/123"
    }
  }
}
```

### Viewing Warnings from Async Actions

The job resource **MAY** surface any warnings that occur during the async operation.

```json
GET /v3/jobs/123
200 OK

{
  "state": "COMPLETED",
  "operation": "hitchhiking.galaxy",
  "status": "done",
  "warnings": [
      {
       "detail": "don't panic",
      },
      {
       "detail": "bring your towel",
      },
  ],
  "links": {
    "self": {
      "href": "https://api.example.org/v3/jobs/123"
    }
  }
}
```

When there are no warnings, `warnings` field will have a value of an empty array.

##  Requesting Specific Fields Resources (Proposal)

> Note: This is a proposal and is not currently implemented on any API endpoints

### Sparse Fields

Clients could wish to see only a specific set of fields from the API. 

The `fields` query parameter **MAY** be provided. 

The `fields`  parameter **MUST** be a comma-delimited list of field names.

If the `fields`  parameter is present, the API **MUST** return only the specified fields.

```json
GET /apps/:guid?fields=guid,name
```
```json
{
  "guid": "some-guid",
  "name": "Zach"
}
```

### Hidden Fields

Certain resources **MAY** not return some fields by default. For example, a field might be computationally expensive, or require a certain permission to return.

The `fields` query parameter **MAY** be provided. 

The `fields`  parameter **MUST** be a comma-delimited list of field names.

If the `fields`  parameter is present, the API **MUST** return the the specified fields in addition to the default set of fields.

Without Fields Parameter:
```
GET /apps/:guid
```
```json
{
  "guid": "some-guid"
}
```

With Fields Parameter:
```
GET /apps/:guid?fields=expensive_field
```
```json
{
  "guid": "some-guid",
  "expensive_field": "$$$$"
}
```

### Proposal: Fields For Sub-Resources

If we want to be able to filter the fields of included resources, we could do something like:
```
GET /v3/apps/:guid?fields=guid,name&fields[droplet]=guid
```
```json
{
  "guid": "some-guid",
  "name": "my-app",
  "included": {
    "droplet": {
      "guid": "droplet-guid"
    }
  }
}
```

## Proposal: Mass Deletes

Currently, users can only delete resources one-by-one or as part of a cascading delete. This would enable users to delete multiple matching resources with a single request.

**Example:**

```json
DELETE /v3/spaces/:guid/routes

202 Accepted
```

