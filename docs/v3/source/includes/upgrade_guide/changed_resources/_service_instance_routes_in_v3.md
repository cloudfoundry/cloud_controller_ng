### Service Instance routes in V3

There is a new resource `service route binding` that represents a binding between a route and a service instance.

Creation/Deletion of bindings is therefore done via that endpoint in v3.

Audit events for route bindings have changed as follows:

|**V2**|**V3**|
|---|---|
audit.service_instance.bind_route | audit.service_route_binding.start_create (async only)<br>audit.service_route_binding.create |
audit.service_instance.unbind_route |audit.service_route_binding.start_delete (async only)<br>audit.service_route_binding.delete |

Read more about the [service route binding resource](#service-route-binding).
