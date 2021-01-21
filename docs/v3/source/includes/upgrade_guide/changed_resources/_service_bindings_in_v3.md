### Service Bindings in V3

#### Combining service bindings and service keys

In v2, two different endpoints `/v2/service_bindings` and `/v2/service_keys`
were used to perform bindings operations for service instances.

In v3, all service bindings that are not route bindings are performed using the [service credential bindings](#service-credential-binding) resource.
Service credential bindings can be of type `app` when it is a binding between a [service instance](#service-instances) and an [application](#apps)
or `key` when it only retrieves the credentials of the service instance. 
The `type` filter can be used to list separately each type.

The required parameters when [creating](#create-a-service-credential-binding) 
a service credential binding are different for each type as defined in the documentation. 

#### Object

The structure of the service credential binding object follows V3 pattern.
If the type is `app` the object will contain a relationship to the app.

#### Retrieving service credential bindings details

The `credentials`, `syslog_drain_url` and `volume_mounts` fields for service credential bindings are not included in the response object of service credential bindings.
`/v3/service_credential_bindings/:guid/details` can be used to retrieve the credentials. 

Read more about the [service credential binding details](#get-a-service-credential-binding-details).

#### Service key operations

In v2, all service keys operations were synchronous.

In v3, all service credential bindings, including those of type `key` are asynchronous if possible.

#### Response mode

When operating on service credential bindings of `user-provided` service instances the API will respond synchronously for all operations.

When operating on service credential bindings of `managed` service instances the API will respond asynchronously and the operation might include communicating to the service broker. Read more about async responses [here](#asynchronous-operations).

#### Audit events

Audit events of type `audit.service_key.start_create` and  `audit.service_key.start_delete` have been added to track when 
an async create or delete `key` service credential binding operation has started. 

Audit events of type `audit.service_binding.update` and `audit.service_key.update` are recorded when metadata update is requested. 

Read more about the [service credential binding resource](#service-credential-binding).
