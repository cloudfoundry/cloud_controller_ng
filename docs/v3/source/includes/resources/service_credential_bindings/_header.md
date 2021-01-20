## Service Credential Binding

Service credential bindings are used to make the details of the connection to a service instance available to an app or a developer.

Service credential bindings can be of type `app` or `key`.

A service credential binding is of type `app` when it is a binding between a [service instance](#service-instances) and an [application](#apps)
Not all services support this binding, as some services deliver value to users directly without integration with an application. 
Field `broker_catalog.features.bindable` from [service plan](#the-service-plan-object) of the service instance can be used to determine if it is bindable.

A service credential binding is of type `key` when it only retrieves the details of the service instance and makes them available to the developer. 

