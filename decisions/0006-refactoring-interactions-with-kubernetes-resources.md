# 6. Refactoring Interactions with Kubernetes Resources

Date: 2020-05-11

## Status

Accepted

## Context

The various components deployed via `cloud_controller_ng` interact with the
Kubernetes API to perform CRUD operations on a variety of Kubernetes Custom
Resource Definitions (CRDs) which are created in the context of a `cf-for-k8s`
deployment such that the Kubernetes API becomes the source of truth for those CF
domain objects (e.g. route resources for apps and build/image resources for app
builds).

Currently, we have individual clients which interact with a specific Kubernetes
API group which translates to a client which is scoped to only a particular
grouping of Kubernetes resources. Currently there are two clients: one to
interact with `kpack`-related resources and one to to interact with app
networking-related resources.

We have found that there is an increasing amount of code duplication and shared
logic/concerns between these two clients and any other such clients we might
introduce, so we would like to take note of some refactoring ideas to mitigate
such concerns.

## Decision

The existing clients currently take on two responsibilities which we'd like to
split out:
1. Translate an object from the CC database into a Kubernetes resource JSON
   object
1. Propagate Kubernetes resource JSON to the Kubernetes API and perform any
   required error handling

#### Translate an object from the CC database

Proposing creating some sort of translation layer which will take various CC
domain objects from the CC database and construct their equivalent Kubernetes
CRs (e.g. CC route object => Route CR).

Seems like this would be difficult to achieve generically, so our first pass can
probably just create a class for each object which needs to be translated.

#### Propagate the Kubernetes resource JSON

We would like to propose creating a single, generic Kubernetes client which
accepts JSON form of any Kubernetes resource and simply propagates the desired
resource to the Kubernetes API. This single, generic client should also continue
to provide elegant, traceable error handling at least as well as we currently
do in the existing `route_crd_client` and the `kpack_client`.

This client should also be the single place where Kubernetes-related properties
we expose are configured and validated.

Would be helpful for this generic client to also provide some sort of
validation, especially if we're providing it with raw JSON.

Something to consider is also providing a generic Kubernetes resource template
with common resource keys to extend from instead of providing the entire JSON
content for a particular resource. For example, all Kubernetes resource contain
a top-level `metadata` key with various nested keys that are often defined
such as `name` or `labels` or `namespace`.

## Consequences

#### Benefits:
- We now only have to configure our interaction with Kubernetes in a single
  place which should make configuration errors more discoverable
  - Implementing this proposal should also some configuration validation we
    don't currently have
- Single, generic client will help mitigate some frustrations we've been having
  in conditionally testing only parts of the CC that need an interaction with
  Kubernetes
  - There's a function `kubernetes_api_configured?` which is implemented in a
    few places that is a source of some of this frustration
  - Primary source of frustration is that the dependency locator attempts to
    instantiate a Kubernetes client always on startup which we don't need for
    most tests
- Single, generic client will also provide for a cleaner separation of concerns
  and make following the code paths for these interactions easier

#### Risks:
- without introducing a third class that wraps the two described, this will make callers more difficult to test -- tests will either need to mock the adapter or have knowledge about what it will send to the client.
