# Context:


The aim of this document is to record how Orphan Mitigation (OM) for service bindings is implemented and the reasoning behind the decisions taken.

[OSBAPI](https://github.com/openservicebrokerapi/servicebroker/blob/v2.15/spec.md#orphan-mitigation) defines Orphan Mitigation as the attempt(s) made by the platform (Cloud Controller) to clear up any resources that may have been created by a Service Broker during an operation that eventually failed. Consequences of having lingering resources in the broker may include higher costs, resource quota consumption, etc.

In this scenario, one of two things can happen:
1. The platform has no record of such resources.

    In this case there is no way for the platform to list failed operations of resources that are not tracked by it. As a result, it is possible the operator ignores such resources may have been created. 
    Even if the operator realizes the failed operation actually created some resources in the service broker, destroying such resources would include direct interaction with the service broker as the platform does not provide tools to delete resources it doesn’t track.
1.  The platform still keeps a record of failed service resources.

    In this case the platform can choose whether to perform OM or defer the choice of when to clean up failed resources to the operator. Deferring to the operator can be beneficial as it allows for more troubleshooting.

As of this document, the Cloud Controller aims to comply with the OSBAPI 2.15 specification. 
The specification states the platform may choose to leave the decision of when OM happens to the operator in case they need to troubleshoot for any scenario. 
So whether Cloud Foundry performs OM in the scenarios OSBAPI outlines as requiring it or not is our choice, as long as there is another mechanism in the platform that the operator can use to remove failed resources at a later stage (i.e. DELETE /v3/service_credential_binding). 
Cloud Foundry shouldn’t perform OM in the scenarios OSBAPI says it is not needed.

## V2

v2 is not fully compliant with OSBAPI 2.15 version regarding OM. Changes needed to be compliant are not backwards compatible so it is difficult to introduce them without releasing a major version. 
The OM spec changed on OSBAPI v2.15 and thus, even when v2 was made compatible with that same version, not all scenarios behave the same. 
Also, in some scenarios the choice was made to give the opportunity to the operator to troubleshoot and not automatically mitigate orphan resources. 
In other scenarios the choice was taken not to implement complicated OM logic in places where commands where available to delete resources and so clean up was deferred to the user.

There is also [this document](https://docs.google.com/document/d/11iXxAciCIQpCvrnzmGoEqQIbIVxpn6VDYlm_SVuq9TU/edit?usp=sharing) that specifies what CC is doing in v2 and what it should be doing that has been shared with the community. 
Although effort has been put over time to keep it accurate, it is not 100% a reflection of what V2 really does.

## V3

In v3 API all operations that require broker communication are done asynchronously. This is one of the main differences from v2 API. 
As a result of this approach CF always has a record of the resource that is being created or deleted. When the broker operation fails, CF still keeps a record of the resource e.g. if a create binding operation fails the CF will have keep a record of that resource and set the state to `create failed`. 
This allows the operator to manually remove the failed resource and it means that there should not be any resources that the service broker has created and CF does not have a record of.

However, we have chosen to keep performing orphan mitigation in many cases in order to keep some level of consistency with the expected behaviour in v2 and to satisfy requirements and issues raised by users.


# Binding
 
## Scenarios when CF will perform OM:

Component     | Status code | Response Body | Notes
--------------| :------------:| --------------| --------
Service Broker| 200 | malformed | 
Service Broker| 201 | malformed | 
Service Broker| 201 | bad data | In the rare case that this might happen, CF would not be able to record the broker response. Safest assumption is to delete the resource from the broker and allow the operator to start over.
Service Broker| 202 | malformed | CF would not be able to record the broker response that might include important properties for continuing the async flow (e.g. operation_id).
Service Broker| 2xx | - | 
Service Broker| 410 | - | This is not a valid error code for a `POST` request. No resource should have been created, however attempting OM does not have any risks.
Service Broker| 422 | Unexpected error | No resource should have been created, however attempting OM does not have any risks.
Service Broker| 5xx | - |
Service Broker| Client Timeout | - 

## Scenarios when CF will NOT perform OM:

Component     | Status code | Response Body |  Comments
--------------| :------------:| --------------| --------
Service Broker| 201 | other | 
Service Broker| 202 | other | 
Service Broker| 401 | - | 
Service Broker| 408 | - | 
Service Broker| 409 | - | 
Service Broker| 422 | Requires app/Async/Concurrency error | 
Service Broker| 4xx | - | 
Cloud Controller| Internal error(1) | - |Different from v2, in v3 there is a record of the resource in the DB. The user can delete the resource after failure. 

# Handling binding last operation broker responses

Cloud Foundry will not attempt any OM for any of the responses from binding Last Operation requests. 
We want to give the operator the possibility of troubleshooting and delete the binding when they see fit, in line with [SI behaviour](https://github.com/cloudfoundry/cloud_controller_ng/issues/1842) our users depend on.

## Unbinding

In event of failure, Cloud Foundry will have the record of the resource and the user can attempt to delete again. 
There is not a clear benefit of implementing any OM logic for such straightforward scenario. 

## Changes from v2 to v3
When possible we have kept the same OM implementation in v2 and v3. Cases when we have diverged have been documented in this doc.

In v3 all types of bindings (including service bindings, service keys and route bindings) have the same OM behaviour.

# Status
Draft

# Consequences:

We are mostly keeping in line with what v2 does, except for the scenarios that do not happen in v3 and the places where the code is significantly simpler and easier to maintain if we moved closer to OSB API. 
As a consequence we might get issues filed regarding misalignment with the spec. However the spec is quite loose and we have good justification for the scenarios we are deviating from it; Hence we are confident this won’t cause future problems.

