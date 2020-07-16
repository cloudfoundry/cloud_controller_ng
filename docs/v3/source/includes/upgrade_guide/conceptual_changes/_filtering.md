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

Filtering inequalities has changed in V3: V3 dispenses with the `q=` preamble,
uses `created_ats` instead of `timestamp` and uses bracket operators (`[lt]`,
`[gt]`, `[lte]`, `[gte]`). For example, to request all audit events occurring on
New Year's Day, one would use the following query: `GET
/v3/audit_events?created_ats[lt]=2020-01-02T00:00:00Z&created_ats[gt]=2019-12-31T23:59:59Z`.

The corresponding V2 query would be `GET
/v2/events?q=timestamp<2020-01-02T00:00:00Z&q=timestamp>2019-12-31T23:59:59Z`.

Filtering on equality has also changed: V3 dispenses with the `q=` preamble and
uses the pluralized field (e.g. `names`) on the left side of the equals sign.
For filtering on inclusion in a set, V3 allows passing multiple values separated
by commas.

For example, to request the organizations by
their name ("finance" and "marketing"), one would use the following query:
`/v3/organizations?names=finance,marketing`

The corresponding V2 query would be `GET
/v2/organizations?q=name%20IN%20finance,marketing`

Read more about [filtering in V3](#filters).
