## Delete a service binding

```
Definition
```

```http
DELETE /v3/service_bindings/:guid HTTP/1.1
```

```
Example Request
```

```shell
curl "https://api.[your-domain.com]/v3/service_bindings/[guid]" \
  -X DELETE \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 204 No Content
```

This endpoint deletes a specific service binding.

### Body Parameters

<p class='no-body-parameters-outer'>
  <span class='no-body-parameters-required'>
    No arguments
  </span>
</p>
