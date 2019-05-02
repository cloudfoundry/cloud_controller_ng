### Delete a buildpack

```
Example Request
```

```shell
curl "https://api.example.org/v3/buildpacks/[guid]" \
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
`DELETE /v3/buildpacks/:guid`

#### Permitted Roles
 |
--- | ---
Admin |
