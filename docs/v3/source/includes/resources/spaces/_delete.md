### Delete a space

When a space is deleted, the user roles associated with the space will be
deleted.

```
Example Request
```

```shell
curl "https://api.example.org/v3/spaces/[guid]" \
  -X DELETE \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 202 Accepted
Location: https://api.example.org/v3/jobs/[guid]
```

#### Definition
`DELETE /v3/spaces/:guid`

#### Permitted roles

Role  | Notes
--- | ---
Admin |
Org Manager |

