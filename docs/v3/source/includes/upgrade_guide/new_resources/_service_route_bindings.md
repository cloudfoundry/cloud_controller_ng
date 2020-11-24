### Service Route Bindings

There is a new resource `service route binding` that represents a binding between a route and a service instance.a

Creation/Deletion of bindings is therefore done via that endpoint in v3.

This resource also supports metadata both in create and update requests.

It has a nested resource for fetching binding parameters from the broker. Parameters are only set during creation.

Read more about the [service route binding resource](#service-route-binding).