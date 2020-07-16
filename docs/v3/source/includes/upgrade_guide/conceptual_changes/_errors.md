<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="errors-v3">Errors</h3>

```
Example Request
```

```shell
curl "https://api.example.org/v2/apps/not-found" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 404 Not Found
Content-Type: application/json

{
   "description": "The app could not be found: not-found",
   "error_code": "CF-AppNotFound",
   "code": 100004
}
```

```
Example Request
```

```shell
curl "https://api.example.org/v3/apps/not-found" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```http
HTTP/1.1 404 Not Found
Content-Type: application/json

{
   "errors": [
      {
         "detail": "App not found",
         "title": "CF-ResourceNotFound",
         "code": 10010
      }
   ]
}
```

The V3 API returns an array of errors instead of a single error like in V2.

Clients may wish to display all returned errors.

