### Terminate a process instance

```
Example Request
```

```shell
curl "https://api.example.org/v3/processes/[guid]/instances/[index]" \
  -X DELETE \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 204 No Content
```

Terminate an instance of a specific process. Health management will eventually restart the instance.

This allows a user to stop a single misbehaving instance of a process.

#### Definition
`DELETE /v3/processes/:guid/instances/:index` <br>
`DELETE /v3/apps/:guid/processes/:type/instances/:index`

#### Permitted Roles
 |
--- | ---
Space Developer |
Admin |