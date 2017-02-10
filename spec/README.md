# Testing the Cloud Controller

## External to the Cloud Controller

### [CF Acceptance Tests](https://github.com/cloudfoundry/cf-acceptance-tests/)

These tests run against a full Cloud Foundry deployment. They should be used to test integrations between CC an other Cloud Foundry components. Because they are comparatively more expensive to run than other types of testing, they are typically not used for behavior that is only relevant to the CC.

### [Sync Integration Tests](https://github.com/cloudfoundry/sync-integration-tests)

These test desired and actual app state syncing between Cloud Controller and Diego. It forces Cloud Controller's and Diego's knowledge of app states to diverge so that Cloud Controller's sync process has to reconcile them.

## Within the Cloud Controller Code Base

### Request

High-level API specs for the Cloud Controller API. The full JSON response should be tested here. They should fully integrate through the Cloud Controller, but stub external integrations. These should generally just cover the happy path; edge cases, conditionals, and more specific behaviors should be tested in lower level unit tests. If you are testing an if statement here, you are doing it wrong. Go home!

### Unit

Unit tests form the bulk of the CC's tests. Despite their name, they often integrate with one of the supported databases. They also may test multiple classes/modules.

#### Controller

Controller tests typically integrated with several collaborators, but handle edge cases specific to the controller's responsibilities: serving status codes with appropriate response bodies, and handling permissions.

#### API Version Spec

This [test](spec/api/api_version_spec.rb) exists to remind developers when they are making user facing changes to the API, and to be mindful of any potentially backwards incompatible changes. 

### Service Broker API Compatibility

Ensures backwards compatibility with previous minor versions of the [v2 Service Broker API](http://docs.cloudfoundry.org/services/api.html). As each minor version builds on the functionality
of its predecessors, the test for each minor version tests ONLY the changes introduced in that minor version.
The intent is that these tests should not have to be changed as we add
new minor versions of the Service Broker API. To enforce this, `broker_api_versions_spec.rb` will fail
whenver the content of any of the api tests changes.

These tests only exercise the happy path, make minimal assertions against the CC API
(usually only that the response is not a failure), and assert mostly that the correct requests are
sent to the service broker.

Due to the fact that new optional fields will be added
to requests sent to the broker in the future, any assertions on request parameters should that the
expected keys are **included**, not that the exact set of fields is sent. For example, assert that
a provision request includes the plan_id, but do not assert that the exact set of keys present in
version 2.1 are sent, as this test will break as later minor versions are added.

### Deprecated Test Suites

It is important that these tests still pass, but try not to write any more of them. For bonus points, move the test coverage from the deprecated suites to another (undeprecated) test suite.

#### Integration Tests

Used to test integration with [NATs](https://github.com/cloudfoundry/nats-release) & the [DEA](https://github.com/cloudfoundry/dea_ng). Will be removed once support for DEA is dropped.

#### V2 API Doc Tests

Previously used to both generate the v2 API docs and test the user facing JSON response for the v2 API. Instead, write a request spec.
