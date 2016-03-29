## Delete a droplet

```
Definition
```

```http
DELETE /v3/droplets/:guid HTTP/1.1
```

```
Example Request
```

```shell
curl "https://api.[your-domain.com]/v3/droplets/[guid]" \
  -X DELETE \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 204 No Content
```

This endpoint deletes a specific droplet.

### Body Parameters

<p class='no-body-parameters-outer'>
  <span class='no-body-parameters-required'>
    No arguments
  </span>
</p>
