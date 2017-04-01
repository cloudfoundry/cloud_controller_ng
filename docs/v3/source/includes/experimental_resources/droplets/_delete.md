### Delete a droplet

```
Example Request
```

```shell
curl "https://api.example.org/v3/droplets/[guid]" \
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
`DELETE /v3/droplets/:guid`

#### Permitted Roles
 |
--- | ---
Space Developer |
Admin |