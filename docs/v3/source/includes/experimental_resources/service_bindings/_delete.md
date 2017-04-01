### Delete a service binding

```
Example Request
```

```shell
curl "https://api.example.org/v3/service_bindings/[guid]" \
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
`DELETE /v3/service_bindings/:guid`

#### Permitted Roles
 |
--- | ---
Space Developer |
Admin |