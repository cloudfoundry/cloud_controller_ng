### Service Instances in V3

#### Combining managed and user-provided service instances

In v2, two different endpoints `v2/service_instances` and `v2/user_provided_service_instances`
were used to perform operations on service instances according to their types.

In v3, all service instance operations are performed using the `service instance` resource, regardless of the type.
Service instances can be of type `managed` or `user-provided` and the `type` filter can be used to list each type.

The required parameters when creating and updating a service instance are different for each type as defined in [this](#create-a-service-instance) documentation. 
Each type also has type specific fields. Certain fields are omitted when they do not apply to the type of the service instance.

#### Response mode

When operating on service instances of type `user-provided` the API will respond synchronously for all operations.
When the service instance type is `managed` the API will respond asynchronously and the operation might include communicating to the service broker. Read more about async responses [here](#asynchronous-operations).

#### Listing bindings

In v2, there were specific endpoints `/v2/service_instances/:guid/service_bindings` and `/v2/user_provided_service_instances/:guid/service_bindings` 
to retrieve the bindings for managed and user-provided service instances.

In v3, service bindings of a service instance can be retrieved by filtering the `v3/service_credential_binding` by `service_instance_guids`. 

Read more about the [service instance resource](#service-instances).
