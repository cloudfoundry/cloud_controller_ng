### Get a usage event

```
Example Request
```

```shell
curl "https://api.example.org/v3/usage_events/[guid]" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "guid": "a595fe2f-01ff-4965-a50c-290258ab8582",
  "created_at": "2020-05-28T16:41:23Z",
  "updated_at": "2020-05-28T16:41:26Z",
  "type": "app"
}
```

Retrieve a usage event.

#### Definition

`GET /v3/usage_events/:guid`

#### Permitted Roles
 |
--- | ---
Admin |
Admin Read-Only |
Global Auditor |
