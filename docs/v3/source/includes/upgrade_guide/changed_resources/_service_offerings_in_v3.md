### Service Offerings in V3

Services resource is now replaced by [service offerings resource](#service-offerings) at `/v3/service_offerings`

Some services related endpoints nested in other resources have been translated to filters on `service_offerings`, with the advantage that filters accept multiple values and can be combined.

`GET /v2/organizations/:guid/services` is now `GET /v3/service_offerings?organization_ids=guid`.

`GET /v2/spaces/:guid/services` is now `GET /v3/service_offerings?space_ids=guid`

`GET /v2/services/:guid/service_plans` is now a filter on the service plan resource: `GET /v3/service_plans?service_offering_guids=guid`. This link can also be found in the object's `links` section.


In V2, `service_broker_name` was returned in the response. V3 returns this value only if requested using the [`fields` syntax](#fields). Refer to [service offerings resource](#service-offerings) for further information. A link to the `Service Broker` resource is included in the object's `links` section.  

The structure of the service offering object as well as some attribute names have changed from V2 to V3:

|**V2**|**V3**|
|---|---|
label | name
active | available
bindable | broker_catalog.features.bindable
extra | shareable, broker_catalog.metadata
unique_id | broker_catalog.id
plan_updateable | broker_catalog.features.plan_updateable
instances_retrievable | broker_catalog.features.instances_retrievable
bindings_retrievable | broker_catalog.features.bindings_retrievable
service_broker_guid | relationships.service_broker.data.guid


Read more about the [service offering resource](#service-offerings).
