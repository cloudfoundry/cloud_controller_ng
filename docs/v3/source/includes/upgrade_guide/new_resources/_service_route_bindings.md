### Service Route Bindings

There is a new resource `service route binding` that represents a binding between a route and a service instance.

Creation/Deletion of these bindings is therefore done via that endpoint in v3.

This resource also supports metadata both in create and update requests.
Audit event of type `audit.service_route_binding.update` is recorded when metadata update is requested.

It has a nested resource for fetching binding parameters from the broker. Parameters are only set during creation.

Read more about the [service route binding resource](#service-route-binding).