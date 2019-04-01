### Delete a route mapping

```
Example Request
```

```shell
curl "https://api.example.org/v3/route_mappings/[guid]" \
  -X DELETE \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 204 No Content
```

#### Definition
`DELETE /v3/route_mappings/:guid`

#### Permitted Roles
 |
--- | ---
Space Developer |
Admin |