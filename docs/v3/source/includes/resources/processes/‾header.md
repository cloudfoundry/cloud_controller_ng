## Processes

Processes define the runnable units of an app. An app can have multiple process types, each with differing commands and scale.
Processes for an app are defined by the buildpack used to stage the app and can be customized by including a [Procfile](#procfiles) in the application source.

#### Web process type
* By default, a newly created app will come with one instance of the `web` process and all other process types are scaled to zero
* Scale the `web` process to zero if it is not required for your app
* Unless otherwise specified, all routes will be mapped to the `web` process by default
