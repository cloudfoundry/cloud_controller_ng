### Delete a service credential binding

```
Example Request
```

```shell
curl "https://api.example.org/v3/service_credential_bindings/[guid]" \
  -X DELETE \
  -H "Authorization: bearer [token]"
```

```
Example Response for User-provided Service Instances
```

```http
HTTP/1.1 204 No Content
```

```
Example Response for Managed Service Instance
```

```http
HTTP/1.1 501 Not Implemented
``` 

This endpoint deletes a service credential binding. When deleting credential bindings originated from user provided 
service instances, the delete operation does not require interactions with service brokers, therefore the API will 
respond synchronously to the delete request. Deleting credential bindings from managed service instances is not supported
at this point. 

#### Definition
`DELETE /v3/service_credential_bindings/:guid`

#### Permitted Roles
 |
--- | ---
Admin |
Space Developer |
