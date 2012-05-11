Principles of Operation
=======================

Overview
--------

The Cloud Foundry V2 family of APIs follow RESTful principles.
The primary goal of the V2 API is to support the new entities in
the Team Edition release, and to address the shortcomings of the V1 in terms
features and consistency.  The specific high level goals are as follows:

* **Consistency** accross all resource URLs, parameters, request/response
  bodies, and error responses.

* **Partial updates** of a resource can be performed by providing a subset of
  the resources' attributes.  This is in contrast to the V1 API which required a
  read-modify-write cycle to update an attribute.

* **Pagination** support for each of the collections.

* **Filtering** support for each of the collections.

Authentication
--------------

Authentication is performed by providing a UAA Token in the _Authorization_ HTTP header.

**TBD:** insert snippet from Dale about the responses if the Token isn't provided,
or if is invalid, expired, etc.

Versioning
----------

The API version is specified in the URL, e.g. `POST /v2/foo_bars` to
create a new FooBar using version 2 of the API.

Debugging
---------

The V2 API endpoints may optionally return a GUID in the `X-VCAP-Request-ID`
HTTP header.  The API endpoint will ideally log this GUID on all log lines
and pass it to associated systems to assist with cross component log collation.

Basic Operations
----------------

Operations on resources follow standard REST conventions.  Requests and
responses for resources are JSON encoded.  Error responses are also JSON
encoded.

### Common Attributes in Response Bodies

Reponse bodies have 2 components, a `metadata` and `entity` sections.

The following attributes are contained in the `metadata` section:

| Attribute  | Description                                                                         |
| ---------  | -----------                                                                         |
| id         | Stable id for the resource.                                                         |
| url        | URL for the resource.                                                               |
| created_at | Date/Timestamp the resource was created, e.g. "2012-01-01 13:42:00 -0700"           |
| updated_at | Date/Timestamp the resource was updated.  null if the resource has not been updated |


### Creating Resources

`POST /v2/foo_bars` creates a FooBar.

The attributes for new FooBar are specified in a JSON encoded request body.

A successful `POST` results in an HTTP 201 with the `Location`
header set to the URL of the newly created resource.  The API endpoint should
return the Etag HTTP header for later use by the client
in support of opportunistic concurency.

The attributes for the FooBar are returned in a JSON encoded response body.

### Reading Resources

`GET /v2/foo_bars/:id` returns the attributes for a specific
FooBar.

A successful `GET` results in an HTTP 200.  The API endpoint should set the
Etag HTTP header for later use in opportunistic concurency.

The attributes for the FooBar are returned in a JSON encoded response body.

### Listing Resources

`GET /v2/foo_bars` lists the FooBars.

Successful `GET` requests return HTTP 200.

The attributes for the FooBar are returned in a JSON encoded response body.

#### Pagination

All `GET` requests to collections are implicitly paginated, i.e. `GET
/v2/foo_bars` initiates a paginated request/response across all FooBars.

##### Pagination Response Attributes

A paginated reponse contains the following attributes:

| Attribute     | Description                                                                                       |
| ---------     | -----------                                                                                       |
| total_results | Total number of results in the entire data set.                                                   |
| prev_url      | URL used to fetch the previous set of results in the paginated response.  null on the first call. |
| next_url      | URL used to fetch the next set of ressults in the paginated response.  null on the last call.     |
| resources     | Array of resources as returned by a GET on the resource id.                                       |

The resources are expanded by default because in that is what is desired in the
common use cases.

##### Pagination Parameters

The following optional parameters may be specified in the initial GET, or
included in the query string to `prev_url` or `next_url`.

| Parameter   | Description                                                          |
| ---------   | -----------                                                          |
| limit       | Maximum number of results to return.                                 |
| offset      | Offset from which to start iteration.                                |
| urls-only   | If 1, only return a list of urls; do not expand metadata or resource attributues |

If the client is going to iterate through the entire dataset, they are
encouraged to follow `next_url` rather than iterating by setting offset
to the last offset + limit.

Example:

Request: `GET /v2/foo_bars?limit=2`

Response:

```json
{
  "total_results": 10029,
  "prev_url": null,
  "next_url": "/v2/an_opaque_url",
  "resources": [
    {
      "metadata": {
        "id": 5,
        "url": "/v2/foo_bars/5",
        "created_at":"2012-01-01 13:42:00 -0700",
        "updated_at":"2012-01-05 08:31:00 -0700"
      },
      "entity": {
        "name": "some name",
        "instances": 3
      }
    },
    {
      "metadata": {
        "id": 7,
        "url": "/v2/foo_bars/7",
        "created_at":"2012-01-01 19:45:00 -0700",
        "updated_at":"2012-01-04 20:27:00 -0700"
      },
      "entity": {
        "name": "some other name",
        "instances": 2
      }
    }
  ]
}
```

#### Search/Filtering

Searching and Filtering are peformed via the `q` query parameter.  The value of
the `q` parameter is a key value pair containing the resource attribute name
and the query value, e.g: `GET /v2/foo_bars?q=name:some*` would return
both records shown in the pagination example above.

String query values may contain a `*` which will be treated at a shell style
glob.

Query values may also contain `>` or `<`, e.g. `GET /v2/foo_bars?q=instances:>2`.

The API endpoint may return an error if the resulting query performs an
unindexed search.

### Deleting Resources

`DELETE /v2/foo_bars/:id` deletes a specific FooBar.

The caller may specify the `If-Match` HTTP header to enable opportunistic
concurrency.  This is not required.  If there is an opportunistic concurrency
failure, the API enpoint should return HTTP 412.

A successful `DELETE` operation results in a 204.

### Updating Resources

`PUT` differs from standard convention.  In order to avoid a read-modify-write
cycle when updating a single attribute, `PUT` is handled as if the `PATCH` verb
were used.  Specically, if a resource with URL `/v2/foo_bars/99` has attributes

```json
{
  "metadata": {
    "id": 99,
    "url": "/v2/foo_bars/99",
    "created_at":"2012-01-01 13:42:00 -0700",
    "updated_at":"2012-01-03 09:15:00 -0700"
  },
  "entity": {
    "name": "some foobar",
    "instances": 2,
  }
}
```

then a `PUT /v2/foo_bars/99` with a requrest body of `{"instances":3}` results
in a resource with the following attributes

```json
{
  "metadata": {
    "id": 99,
    "url": "/v2/foo_bars/99",
    "created_at":"2012-01-01 13:42:00 -0700",
    "updated_at":"2012-01-05 08:31:00 -0700"
  },
  "entity": {
    "name": "some foobar",
    "instances": 3,
  }
}
```

A sucessful `PUT` results in an HTTP 200.

The caller may specify the `If-Match` HTTP header to enable opportunistic
concurrency.  This is not required.  If there is an opportunistic concurrency
failure, the API enpoint should return HTTP 412.

The attributes for the updated FooBar are returned in a JSON encoded response body.

Note: version 3 of this API might require `PUT` to contain the full list of required
attributes and such partial updates might only be supported via the HTTP
`PATCH` verb.

Associations
------------

### N-to-One

#### Reading N-to-One Associations

N-to-one relationships are indicated by an id and url attribute for the other
resource.  For example, if a FooBar has a 1-to-1 relationship with a Baz,
a `GET /v2/FooBar/:id` will return the following attributes related to
the associated Baz (other attributes omitted)

```json
{
  "baz_id": 5,
  "baz_url": "/v2/bazs/5"
}
```

#### Setting N-to-One Associations

Setting an n-to-one association is done during the initial `POST` for the
resource or during an update via `PUT`.  The caller only specifies the id,
not the url.  For example, to update change the Baz associated with the FooBar
in the example above, the caller could issue a
`PUT /v2/FooBar/:id` with a body of `{ "baz_id": 10 }`.  To disassociate
the resources, set the id to `null`.

### N-to-Many

#### Reading N-to-Many Associations

N-to-many relationships may be
N-to-Many relationships are indicated by a url attribute for the other
collection of resources.  For example, if a FooBaz has multiple Bars, a
`GET /v2/FooBaz/:id` will return the following attribute (other
attributes omitted)

```json
{
  "bars_url": "/v2/foo_baz/bars"
}
```

The URL will initiated a paginated response.

#### Setting N-to-Many Associations

Setting an n-to-many association is done during the initial `POST` for the
resource, during an update via `PUT`.

To create the association during a `POST` or to edit it with a `PUT`, supply a
an array of ids.  For example, in the FooBaz has multiple Bars example
above, a caller could issue a `POST /v2/FooBaz` with a body of `{ "bar_ids": [1,
5, 10]}` to make an initial assocation of the new FooBaz with Bars with ids 1,
5 and 10 (other attributes omitted).  Similarly, a `PUT` will update the
assocations between the resources to only those provided in the list.

Adding and removing elements from a large collection would be onerous if the
entire list had to be provided every time.  To controll how the list of ids are
added to the collection, supply the following query parameter
`collection-method=add`, or `collection-method=replace`.  If the collection-method
is not supplied, it defaults to replace.

(An alternative to the query parameters would have been to use POST and DELETE
on the association url, however, this makes batch operations somewhat easier,
and allows modifications to the association to be transacted with other changes
to the resource.)

### Inlining Relationships

There are common Cloud Foundary use cases that would require a relatively high
number of API calls if the relation URLs have to be fetched when traversing a
set of resources, e.g. when performing the calls necessary to satisfy a `vmc
apps` command line call.  In these cases, the caller intends to walk the entire
tree of relationships.

To inline relationships, the caller may specify a `inline-relations-depth` query
parameter for a `GET` request.  A value of 0 results in the default behavior of
not inlining any of the relations and only URLs as described above are
returned.  A value of N > 0 results in the direct expansion of relations
inline in the response, but URLs are provided for the next level of relations.

For example, in the request below a FooBar has a to-many relationship to Bars
and Bars has a to-one relationship with a Baz.  Setting the
`inline-relations-depth=1` results in bars being exapanded but not baz.

Request: `GET /v2/FooBar/5?inline-relations-depth=1`

Response:

```json
{
  "metadata": {
    "id": 5,
    "url": "/v2/foo_bars/5",
    "created_at":"2012-01-01 13:42:00 -0700",
    "updated_at":"2012-01-05 08:31:00 -0700"
  },
  "entity": {
    "name": "some foobar",
    "bars": [
      {
        "metadata": {
          "id": 10,
          "url": "/v2/bar/5",
          "created_at":"2012-01-03 11:22:00 -0700",
          "updated_at":"2012-01-07 09:03:00 -0700"
        },
        "entity": {
          "name": "some bar",
          "baz_id": 99,
          "baz_url": "/v2/bazs/99"
        }
      },
    ]
  }
}
```

Specifiying `inline-releations-depth` > 1 should not result in an circular
expansion of resources.  For example, if there is a bidirectional relationship
between two resources, e.g. an Organization has many Users and a User is a
member of many Organizations, then the response to `GET
/v2/organizations/:id?inline-releations-depth=10`
should not expand the Organizations a User belongs to.  Doing so would result
in an expansion loop.  The User expansion should provide a `organizations_url`
instead.

Errors
------

Appropriate HTTP response codes are returned as part of the HTTP response
header, i.e. 400 if the request body can not be parsed, 404 if an operation
is requested on a resource that doesn't exist, etc.

In addition to the HTTP response code, an error response is returned in the
reponse body.  The error response is json encoded with the following
attributes:

| Attribute    | Description                             |
| ---------    | -----------                             |
| code         | Unique numeric resposne code            |
| descriptions | Human readable description of the error |

Actions
-------

Actions are modeled as an update to desired state in the system, i.e.
to start a FooBar resource with id 5 and set the instance count
to 10, the caller would `PUT /v2/foo_bar/5` with a request body of
`{ "state": "STARTED", "instances": 10 }`.
