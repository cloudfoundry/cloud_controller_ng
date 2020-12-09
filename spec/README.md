# Testing the Cloud Controller

## External to the Cloud Controller

### [CF Acceptance Tests (CATS)](https://github.com/cloudfoundry/cf-acceptance-tests/)

These tests run against a full Cloud Foundry deployment. They should be used to test integrations between CC and other Cloud Foundry components. Because they are run by many teams and are comparatively more expensive to run than other types of testing, CATS are typically restricted to testing happy-path scenarios that require a fully integrated CF.

### [Sync Integration Tests (SITS)](https://github.com/cloudfoundry/sync-integration-tests)

These test desired and actual app state syncing between Cloud Controller and Diego. It forces Cloud Controller's and Diego's knowledge of app states to diverge so that Cloud Controller's sync process has to reconcile them.

### [Banausic Acceptance & Regression Avoidance Suite (BARAS)](https://github.com/cloudfoundry/capi-bara-tests)

These tests run against a full Cloud Foundry deployment. These are similar in structure, format, and cost to CATS but are only run and maintained by the CAPI team. This is where we will test non-happy-path integrations between the Cloud Controller and other components that do not otherwise belong in CATS. If a test requires a fully integrated CF environment, but is likely only to be of interest to the CAPI team, the BARAS are a good place to put it.

## Within the Cloud Controller Code Base

### Request

High-level API specs for the Cloud Controller API. The full JSON response should be tested here. They should fully integrate through the Cloud Controller, but stub external integrations. These should generally just cover the happy path; edge cases, conditionals, and more specific behaviors should be tested in lower level unit tests. If you are testing an if statement here, you are doing it wrong. Go home!

**Update:** We are currently experimenting with writing Request specs _instead_ of Controller specs. This means that newer Request specs may fulfilling some of the Controller spec responsibilities such as validating permissions, status codes, and response bodies.
See [this ADR](https://github.com/cloudfoundry/cloud_controller_ng/blob/main/decisions/0003-switching-to-request-specs-for-controllers.md) for more information on this experiment.

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
To view the docs locally, cd into the `docs/v2` folder, run `python -mSimpleHTTPServer`, and navigate to `http://localhost:8000`.

## Running Tests In Preloaded (Fast) Mode:

Running unit tests is a good thing, but it can be annoying waiting for
the ruby interpreter to load and then initialize `rspec` every single
time you make a change. Fortunately, many other people have run into
this same frustration and published their solutions to the problem. We
use the `spork` library to speed up the `edit-run-fix` cycle.

### Running Individual Tests

In one terminal, change to the `Cloud Controller` root directory and run `bundle exec spork`

In a separate terminal, you can run selected unit tests quickly by running them with the `--drb` option, as in:

    bundle exec rspec --drb spec/unit/models/services/service_plan_visibility_spec.rb

You can configure your IDE to take advantage of spork by inserting the `--drb` option. If `spork` isn't running `rspec` will ignore the `--drb` option and run the test the usual slower way.

Press Ctrl-C in the first terminal to stop running `spork`.

### Running Tests Automatically When Files Change

In one terminal, change to the `Cloud Controller` root directory and run `bundle exec scripts/file-watcher.rb`

As files change, they, or their related spec files, will be run automatically.

Press Ctrl-C to stop running `file-watcher.rb`.
