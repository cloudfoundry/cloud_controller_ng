### Service Instances in V3

#### Combining managed and user-provided service instances

In v2, two different endpoints `/v2/service_instances` and `/v2/user_provided_service_instances`
were used to perform operations on service instances according to their types.

In v3, all service instance operations are performed using the [service instance](#service-instances) resource, regardless of the type.
Service instances can be of type `managed` when it is an instantiation of a [service offering](#service-offerings) registered with CF 
or `user-provided` when it describes an instance of an offering that is not registered with CF. 
The `type` filter can be used to separately list each type.

The required parameters when [creating](#create-a-service-instance) and [updating](#update-a-service-instance) 
a service instance are different for each type as defined in their respective documentation. 

#### Object

The structure of the service instances object as well as some attribute names have changed from V2 to V3.
Each service instance type has type specific fields. Certain fields are omitted when they do not apply to the type of the service instance.

|**V2**|**V3**|
|---|---|
type valid values `managed_service_instance` and `user_provided_service_instance` | type valid values `managed` and `user-provided` |
entity.service_plan_guid | relationships.service_plan.data.guid |
entity.space_guid | relationships.space.data.guid |

#### User provided service instance credentials

The `credentials` field for user provided service instances is not included in the response object of service_instances.
`/v3/service_instances/:guid/credentials` can be used to retrieve the credentials. 

Read more about the [service instance credential](#get-credentials-for-a-user-provided-service-instance).

#### Response mode

When operating on service instances of type `user-provided` the API will respond synchronously for all operations.

When the service instance type is `managed` the API will respond asynchronously and the operation might include communicating to the service broker. Read more about async responses [here](#asynchronous-operations).

#### Listing bindings

In v2, there were specific endpoints `/v2/service_instances/:guid/service_bindings`, `/v2/service_instances/:guid/service_keys` 
and `/v2/user_provided_service_instances/:guid/service_bindings` to retrieve the service bindings and service keys for managed and user-provided service instances.

In v3, the [service credential bindings](#list-service-credential-bindings) can be filtered by `service_instance_guids` to retrieve the bindings of any service instance. 

#### Service instance route bindings

In v2, binding a service instance to a route was done as a relationship request for the service instance.

In v3, there is a new resource [service route binding](#service-route-bindings) that represents a binding between a route and a service instance.
Creation and deletion of route bindings is therefore done via that endpoint in v3.

Audit events for route bindings have changed as follows:

|**V2**|**V3**|
|---|---|
audit.service_instance.bind_route | audit.service_route_binding.start_create (async only)<br>audit.service_route_binding.create |
audit.service_instance.unbind_route |audit.service_route_binding.start_delete (async only)<br>audit.service_route_binding.delete |

Read more about the [service instance resource](#service-instances).
