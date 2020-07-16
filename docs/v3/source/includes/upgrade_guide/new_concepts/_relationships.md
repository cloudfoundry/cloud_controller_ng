<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="relationships-v3">Relationships</h3>


```
Example Request
```

```shell
curl "https://api.example.org/v3/apps" \
  -X POST \
  -H "Authorization: bearer [token]"
  -d '{
        "name": "testapp",
        "relationships": {
         "space": { "data": { "guid": "1234" }}
        }
      }'
```

Relationships represent associations between resources: For example, every space belongs in an organization, and every app belongs in a space. The V3 API can create, read, update, and delete these associations.

In the example request we create an app with a relationship to a specific space.

One can retrieve or update a resource's relationships. For example, to retrieve an app's relationship to its space with the `/v3/apps/:app_guid/relationships/space` endpoint.

For more information, refer to the [relationships](#relationships).

