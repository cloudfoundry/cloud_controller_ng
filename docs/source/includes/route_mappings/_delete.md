## Delete a route mapping

```
Definition
```

```http
DELETE /v3/route_mappings/:guid HTTP/1.1
```

```
Example Request
```

```shell
curl "https://api.[your-domain.com]/v3/route_mappings/[guid]" \
  -X DELETE \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 204 No Content
```

This endpoint deletes a specific route mapping.

### Body Parameters

<p class='no-body-parameters-outer'>
  <span class='no-body-parameters-required'>
    No arguments
  </span>
</p>
