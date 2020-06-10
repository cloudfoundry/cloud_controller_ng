### Asynchronous Operations

Unlike V2, clients cannot opt-in for asynchronous responses from endpoints. Instead, endpoints that require asynchronous processing will return `202 Accepted` with a Location header pointing to the job resource to poll. Endpoints that do not require asynchronous processing will respond synchronously.

For clients that want to report the outcome of an asynchronous operation, the expected pattern is to poll the job in the Location header until its `state` is no longer `PROCESSING`. If the job's `state` is `FAILED`, the `errors` field will contain any errors that occurred during the operation.

An example of an asynchronous endpoint is the [delete app endpoint](#delete-an-app).

Read more about [the job resource](#jobs).

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

