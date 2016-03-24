## Terminate a process instance for an app

```
Definition
```

```http
DELETE /v3/apps/:guid/processes/:type/instances/:index HTTP/1.1
```

```
Example Request
```

```shell
curl "https://api.[your-domain.com]/v3/apps/[guid]/processes/[type]/instances/[index]" \
  -X DELETE \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 204 No Content
```

This endpoint terminates an instance of a specific process belonging to an app. Health management will eventually restart the instance.

This allows a user to stop a single misbehaving instance of a process.

### Body Parameters

<p class='no-body-parameters-outer'>
  <span class='no-body-parameters-required'>
    No arguments
  </span>
</p>
