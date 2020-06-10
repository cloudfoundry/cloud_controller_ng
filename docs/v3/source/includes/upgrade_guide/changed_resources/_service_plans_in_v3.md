### Service Plans in V3

Some service plans related endpoints nested in other resources have been translated to filters on service plans, with the advantage that filters accept multiple values and can be combined.

`GET /v2/services/:guid/service_plans` -> `GET /v3/service_plans?service_offering_guids=guid`

Changing plan visibility to `Public` is not a PUT operation anymore. To change visibility use the [service plan visibility resource](#service-plan-visibility)

The structure of the service plan object as well as some attribute names have changed from V2 to V3:

|**V2**|**V3**|
|---|---|
active | available
bindable | broker_catalog.features.bindable
extra | broker_catalog.metadata
public | `visibility_type == 'public'` (see [visibility types](#list-of-visibility-types))
unique_id | broker_catalog.id
plan_updateable | broker_catalog.features.plan_updateable
service_instances_url |  use `service_plan_guids` or `service_plan_names` filter on [service instances resource](#service-instances)
service_url | links.service_offering.href
service_guid | relationships.service_offering.data.guid

Some filters were renamed and changed to accept a list of values:

|**V2**|**V3**|
|---|---|
service_guid | service_offering_guids
service_instance_guid | service_instance_guids
service_broker_guid | service_broker_guids
unique_id | broker_catalog_ids

Read more about the [service plan resource](#service-plans).
