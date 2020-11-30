## Service Route Binding

Service route bindings are relations between a service instance and a route.

Not all service instances support route binding. 
In order to bind to a managed service instance, the service instance should be created from a service offering that has requires route forwarding (`requires=[route_forwarding]`). 
In order to bind to a user-provided service instance, the service instance must have `route_service_url` set.
