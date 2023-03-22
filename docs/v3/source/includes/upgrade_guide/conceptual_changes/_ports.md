### Ports

In V2, users exposed ports on an app by modifying the app's `ports` field.

In V3, users expose ports on a process by creating destinations that map a route to a given app and process. For an app listening on multiple ports, users must create one destination per port. 

Read more about [routes, destinations, and ports](#routes).
