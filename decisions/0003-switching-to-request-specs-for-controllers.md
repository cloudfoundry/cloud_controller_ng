3: Switching to Request Specs for Controllers
================================

Date: 2019-04-16

Status
------

Accepted


Context
-------

There are two approaches to unit testing controllers, neither of which is very useful: If we mock most of the 
dependencies of the controller, our tests become tightly coupled to the implementation and do not give us a
lot of confidence. If we make them more integration-style tests, we end up duplicating lots of tests between the
controller and the request specs.

Additionally, writing controller specs is a discouraged pattern:

> Controller specs can be used to describe the behaviour of Rails controllers. As of version 3.5, however, controller specs are discouraged in favour of request specs (which also focus largely on controllers, but capture other critical aspects of application behaviour as well). Controller specs will continue to be supported until at least version 4.0 (see the release notes for details).

From [RSpec — Controller or Request Specs?][] 

**Warning**: Request specs in the `cloud_controller_ng` codebase are not actually Rspec/Rails request specs (which would be [declared with `type: :request`](https://relishapp.com/rspec/rspec-rails/docs/request-specs/request-spec)), but use [Rack Test](https://github.com/rack-test/rack-test).  Rack Test has similar looking helper methods for making requests (e.g. `get`, `post`, etc), but these take different arguments than the equivalent Rspec methods.

Decision
--------

Moving forward, we will only write request specs for controllers.

Consequences
------------

- Reduced duplication in testing controllers
- Controller spec helpers need to be adjusted to no longer mock out CC app directly - ie they need to be transformed into Request spec helpers.
- Delete controller specs once they've been transitioned to request specs.


[RSpec — Controller or Request Specs?]: https://medium.com/just-tech/rspec-controller-or-request-specs-d93ef563ef11



