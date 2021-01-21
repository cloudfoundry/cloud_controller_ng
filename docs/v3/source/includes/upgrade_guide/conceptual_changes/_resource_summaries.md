### Resource Summaries

V2 provided several endpoints that returned rolled-up summaries (e.g.
`/v2/spaces/:guid/summary` for a space summary, or
`/v2/organizations/:guid/summary` for an organization summary). Although
convenient, these endpoints have been largely removed from V3, for they were
computationally expensive and often returned much more information than
needed.

In V3, to enable better API performance, these usage patterns are
deliberately disallowed. Instead, clients are encouraged to think more carefully
about which information they need and to fetch that information with
multiple API calls and/or by making use of the [`include`
parameter](#including-associated-resources) or [the `fields` parameter](#fields) on certain endpoints.

In V2, summary endpoints provided a way to fetch all resources associated with a
parent resource. In V3, fetch the summary though the associated resource and
filter by the parent resource. See below for examples of summaries in V3.

#### Replacing the space summary endpoint

- To fetch all apps in a space, use `GET /v3/apps?space_guids=<space-guid>`.
  Passing `include=space` will include the space resource in the response body.
- To fetch all service offerings in a space use `GET
  /v3/service_offerings?space_guids=<space-guid>`. Use the
  experimental `fields` parameter to include related information in the response
  body.
- To fetch all service instances in a space use `GET
  /v3/service_instances?space_guids=<space-guid>`. Use the
  experimental `fields` parameter to include related information in the response
  body.
  
##### Replacing the space summary response for service instances

Similar fields to what `/v2/spaces/:guid/summary` was offering for services are available from v3 endpoints.

The table below describes the query parameters needed to retrieve some of those fields using `/v3/service_instances` endpoint.
Same query parameters are available on the request for a single resource.

|**V2 summary fields**|**V3 query**|**V3 response fields**|
|---|---|---|
| services[].service_plan.guid | fields[service_plan]=guid | resources[].included.service_plans[].guid |
| services[].service_plan.name | fields[service_plan]=name | resources[].included.service_plans[].name |
| services[].service_plan.service.guid | fields[service_plan.service_offering]=guid | resources[].included.service_offerings[].guid |
| services[].service_plan.service.label | fields[service_plan.service_offering]=name | resources[].included.service_offerings[].name |
| services[].service_broker_name | fields[service_plan.service_offering.service_broker]=name | resources[].included.service_brokers[].name | 
| shared_from.space_guid | fields[space]=guid | resources[].included.spaces[].guid |
| shared_from.space_name | fields[space]=name | resources[].included.spaces[].name |
| shared_from.organization_name | fields[space.organization]=name | resources[].included.organizations[].name |

The table below describes the query parameters needed to retrieve the sharing information using `/v3/service_instances/:guid/relationships/shared_spaces` endpoint.

|**V2 summary fields**|**V3 query**|**V3 response fields**|
|---|---|---|
| shared_to.space_guid | fields[space]=guid | included.spaces[].guid |
| shared_to.space_name | fields[space]=name | included.spaces[].name |
| shared_to.organization_name | fields[space.organization]=name | included.organizations[].name |

The existing `bound_app_count` field can be found by using the [usage summary endpoint](#get-usage-summary-in-shared-spaces)

Read more about [the `fields` parameter](#fields).

#### Replacing the user summary endpoint

- The user summary was useful for finding organizations and spaces where a user
had roles. In V3, with the introduction of the role resource, you can use `GET
/v3/roles?user_guids=<user-guid>` to list a user's roles. Passing
`include=space,organization` will include the relevant spaces and organizations
in the response body.

#### Usage summary endpoints

There are still a couple of endpoints in V3 that provide a basic summary of
instance and memory usage. See the [org summary](#get-usage-summary) and
[platform summary](#get-platform-usage-summary) endpoints.
