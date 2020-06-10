### Filtering

```
Filters are specified as individual query parameters in V3
```

```shell
curl "https://api.example.org/v2/apps?q=name+IN+dora,broker;stack:cflinuxfs3" \
  -X GET \
  -H "Authorization: bearer [token]"
```

```shell
curl "https://api.example.org/v3/apps?names=dora,broker&stacks=cflinuxfs3" \
  -X GET \
  -H "Authorization: bearer [token]"
```

Filtering resources no longer uses V2's query syntax. See the example to the right.

A few common filters have been also renamed in V3:

|V2 filter|V3 filter|
|---|---|
|`results-per-page`|`per_page`|
|`page`|`page`|
|`order-by`|`order_by`|
|`order-direction`|N/A<sup>1</sup>|

<sup>1</sup> In V3, order is ascending by default. Prefix the `order_by` value with `-` to make it descending. For example, `?order_by=-name` would order a list of resources by `name` in descending order.

Read more about [filtering in V3](#filtering).
