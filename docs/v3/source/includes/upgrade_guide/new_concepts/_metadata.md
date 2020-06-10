<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="metadata-v3">Metadata</h3>

```
Example Request
```

```shell
curl "https://api.example.org/v3/:resource/:guid" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```
Example Response
```

```json
{
  "...": "...",
  "metadata": {
    "labels": {
      "environment": "production",
      "internet-facing": "false"
    },
    "annotations": {
      "contacts": "Bill tel(1111111) email(bill@fixme)"
    }
  }
}
```

Metadata allows you to tag and query certain API resources with information; metadata does not affect the resource's functionality.

For more details and usage examples, see [metadata](#metadata) or [official CF docs](https://docs.cloudfoundry.org/adminguide/metadata.html).

Note that metadata consists of two keys, `labels` and `annotations`, each of which consists of key-value pairs. API V3 allows filtering by labels (see [label_selector](#labels-and-selectors)) but not by annotations.


