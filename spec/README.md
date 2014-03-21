## Intent of each kind of test

NOTE: This list is incomplete. Please enhance it as you can

### spec/acceptance

These test the full Cloud Controller stack, while stubbing out any external services. The intent is that
integration tests that would otherwise end up in spec/controllers should go here. This folder is distinct
from spec/integration, because those tests actually spin up CC in a separate process along with other
components like UAA. As it is generally more convenient to use WebMock to represent external services, these
tests run the controller in-process.

#### spec/acceptance/broker_api_compatibility

These tests ensure that, as we add new minor versions to the
[v2 Service Broker API](http://docs.cloudfoundry.org/services/api.html), Cloud Controller
continues to work with all previous minor versions. As each minor version builds on the functionality
of its predecessors, the test for each minor version tests ONLY the changes introduced in that minor version.
The intent is that these tests should not have to be changed as we add
new minor versions of the Service Broker API. To enforce this, the broker_api_versions_spec.rb will fail
whenver the content of any of the api tests changes.

These tests only exercise the happy path, make minimal assertions against the CC API
(usually only that the response is not a failure), and assert mostly that the correct requests are
sent to the service broker.

Due to the fact that new optional fields will be added
to requests sent to the broker in the future, any assertions on request parameters should that the
expected keys are **included**, not that the exact set of fields is sent. For example, assert that
a provision request includes the plan_id, but do not assert that the exact set of keys present in
version 2.1 are sent, as this test will break as later minor versions are added.
