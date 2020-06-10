### Including Associated Resources

The `inline-relations-depth` parameter is no longer supported on V3. Instead, some resources support the `include` parameter to selectively include associated resources in the response body.

For example, to include an app's space in the response:
```
cf curl /v3/apps/:guid?include=space
```

In addition, some resources provide the possibility of including specified fields of a related resource.

For example, to include the service broker `name` and `guid` in the service offering's response:
```
cf curl /v3/service_offerings/:guid?fields[service_broker]=name,guid
```

Read more about [the `include` parameter](#include) and [the `fields` parameter](#fields).

