<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="links-v3">Links</h3>

```
Example Request
```

```shell
curl "https://api.example.org/v3/apps/:guid" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```json
{
  "...": "...",
  "links": {
    "self": {
      "href": "http://api.example.com/v3/apps/:guid"
    },
    "space": {
      "href": "http://api.example.com/v3/spaces/:space_guid"
    }
  }
}
```

Links provide URLs to associated resources, relationships, and actions for a resource.
The example links to both the app itself and the space in which it resides.

