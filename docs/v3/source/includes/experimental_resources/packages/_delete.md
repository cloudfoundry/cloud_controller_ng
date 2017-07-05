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
HTTP/1.1 202 Accepted
Location: https://api.example.org/v3/jobs/[guid]
```

#### Definition
`DELETE /v3/packages/:guid`

#### Permitted Roles
 |
--- | ---
Space Developer |
Admin |