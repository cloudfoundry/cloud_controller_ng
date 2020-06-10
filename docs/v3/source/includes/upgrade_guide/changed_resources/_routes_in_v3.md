### Routes in V3

In V2, the route resource represented a URL that could be mapped to an app, and the route mapping resource represented a mapping between a route and an app.

In V3, these concepts have been collapsed into a single route resource. Now, a route can have one or more "destinations" listed on it. These represent a mapping from the route to a resource that can serve traffic (e.g. a process of an app).

Read more about [routes and destinations](#routes).
