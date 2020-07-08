# 9. Reorganize code for interacting with kubernetes

Date: 2020-07-08

## Status

Proposed

Supercedes [6. Refactoring Interactions with Kubernetes Resources](0006-refactoring-interactions-with-kubernetes-resources.md)

## Context

A previous ADR (#6) proposed a new structure for our interactions with
Kubernetes resources and the k8s API. When we attempted to implement the
decisions made there we discovered some problems with the proposal that made it
difficult to implement. Below are the two goals of ADR 6 and the problems they
present.

### Translate an object from the CC database
The initial proposal assumed that we could directly translate from Cloud
Controller models into k8s resources. While this is true for creating new
resources, it doesn't appear to be true when we want to update an existing
resource.

[This line](https://github.com/cloudfoundry/cloud_controller_ng/blob/31a6e5c13b953cf47d443f2a7ce31aa43df4ccfa/lib/cloud_controller/kpack/stager.rb#L18)
from the `Kpack::Stager` illustrates the problem. To update the existing image,
we currently (1) fetch the existing k8s resource, (2) modify a subset of the
fields on that record, then (3) update the resource via the k8s API. How would
this work with the proposed translation layer? Here are some options we
considered: 

1. Fetch the existing k8s resource => Pass it to the translator to update only
   specific fields => Send the result to the k8s API
   - This flow works, but only seems to add complexity without adding value

2. Use the translator to build the k8s resource from scratch => clobber the
   current state of that resource via the k8s API
   - The k8s api
     [appears to use a `resourceVersion` key](https://kubernetes.io/docs/reference/using-api/api-concepts/)
     on the resource to implement optimistic locking. If we clobber the existing
     object, this key will be missing and this may lead to the API rejecting the
     request
   - Any other data that has been added to the existing resource (and cannot be
     derived from the CC model) will be removed.

Having a separate translator object could help avoid code drift should we have 2
or more Ruby classes that are building/manipulating the same type of Kubernetes
resource. However, in the current codebase there is exactly one Ruby class that
manages each type of k8s resource. If this changes we can reevaluate this
decision.

### Propagate the Kubernetes resource JSON
ADR 6 proposed having an interface like `kubectl apply`: a single k8s API client
that takes a k8s resource config and sends it to the correct API endpoint. None
of the 3 ruby clients [mentioned in k8s docs] support this workflow. They all
either provide a separate set of methods for each resource (e.g. `create_image`)
or require you to scope your get/update/etc to a specific resource (e.g.
`client.api('v1').resource('services').create_resource(service)`).

We could write our own code to make this flow possible, but the benefit of that
isn't clear. If anything, having different methods to reflect each
(verb, resource-type) tuple makes it easier to test our interaction with the k8s
API in CC (via `expect(client).to(have_received(:create_image))`). It should
also yield a clear "No method" error if we attempt to use a verb or
resource-type that isn't supported.


## Decision

1. Create a single Ruby class to manage interactions with the k8s API. This
   class will handle translating Kubeclient errors into CC errors and little
   else. We will continue the existing pattern of a separate method for each
   verb + resource-type combination (e.g. `#update_route`)
   - This class is currently called `Kubernetes::ApiClient`

2. Rather than creating a separate translation class, we will maintain the
   current pattern:
   - Each type of k8s resource is managed by exactly one Ruby class
   - That class contains the logic for creating or modifying the k8s resource
     config based on CC models
   - That class delegates to `Kubernetes::ApiClient` to interact with the k8s
     API and handle error translation
   - Current examples of classes that do this: 
     - [`Kpack::Stager`](https://github.com/cloudfoundry/cloud_controller_ng/blob/master/lib/cloud_controller/kpack/stager.rb)
     - [`VCAP::CloudController::KpackBuildpackListFetcher`](https://github.com/cloudfoundry/cloud_controller_ng/blob/master/app/fetchers/kpack_buildpack_list_fetcher.rb)
     - [`Kubernetes::RouteResourceManager`](https://github.com/cloudfoundry/cloud_controller_ng/blob/master/app/fetchers/kpack_buildpack_list_fetcher.rb) (formerly `RouteCrdClient`)

3. Move all k8s-specific classes under a single namespace (e.g. `Kubernetes` or
   `VCAP::CloudController::K8s`)
4. Move all classes that are specific to bosh/VM-based deployments of CF into
   their own namespace as well (e.g. `Vm`, `Bosh`, `Classic`, or `Legacy`)

## Consequences

We make some minor changes to the current structure of our codebase. There is a
risk that more dramatic changes will be needed at a later time, but we'll also
know more then and have more examples of k8s-specific code to draw from for good
patterns.
