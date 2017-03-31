### Delete a package

```
Definition
```

```http
DELETE /v3/packages/:guid HTTP/1.1
```

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