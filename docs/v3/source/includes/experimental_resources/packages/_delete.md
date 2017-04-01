### Delete a package

```
Example Request
```

```shell
curl "https://api.example.org/v3/packages/[guid]" \
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
`DELETE /v3/packages/:guid`

#### Permitted Roles
 |
--- | ---
Space Developer |
Admin |