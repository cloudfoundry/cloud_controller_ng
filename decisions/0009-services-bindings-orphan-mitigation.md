# Context:

The aim of this document is to record how Orphan Mitigation (OM) for service instances and service bindings is implemented 
and the reasoning behind the decisions taken.

[OSBAPI](https://github.com/openservicebrokerapi/servicebroker/blob/v2.15/spec.md#orphan-mitigation) defines 
Orphan Mitigation as the attempt(s) made by the platform (Cloud Controller) to clear up any resources that may have been 
created by a Service Broker during an operation that eventually failed. Consequences of having lingering resources in the 
broker may include higher costs, resource quota consumption, etc.

In this scenario, one of two things can happen:
1. The platform has no record of such resources.

   In this case there is no way for the platform to list failed operations of resources that are not tracked by it. 
   As a result, it is possible the operator ignores such resources may have been created. 
   Even if the operator realizes the failed operation actually created some resources in the service broker, 
   destroying such resources would include direct interaction with the service broker as the platform does not 
   provide tools to delete resources it doesn't track.
   
1.  The platform still keeps a record of failed service resources.

    In this case the platform can choose whether to perform OM or defer the choice of when to clean up failed resources 
    to the operator. Deferring to the operator can be beneficial as it allows for more troubleshooting.

As of this document, the Cloud Controller aims to comply with the OSBAPI 2.15 specification. 
The specification states the platform may choose to leave the decision of when OM happens to the operator in case they 
need to troubleshoot for any scenario. So whether Cloud Foundry performs OM in the scenarios OSBAPI outlines as requiring 
it or not is our choice, as long as there is another mechanism in the platform that the operator can use to remove failed 
resources at a later stage (i.e. `DELETE /v3/service_instances` or `DELETE /v3/service_credential_bindings`). 
Cloud Foundry shouldn’t perform OM in the scenarios OSBAPI says it is not needed.

## V2

v2 is not fully compliant with OSBAPI 2.15 version regarding OM. Changes needed to be compliant are not backwards compatible 
so it is difficult to introduce them without releasing a major version. The OM spec changed on OSBAPI v2.15 and thus, even 
when v2 was made compatible with that same version, not all scenarios behave the same. Also, in some scenarios the choice 
was made to give the opportunity to the operator to troubleshoot and not automatically mitigate orphan resources. In other 
scenarios the choice was taken not to implement complicated OM logic in places where commands where available to delete 
resources and so clean up was deferred to the user.

There is also [this document](https://docs.google.com/document/d/11iXxAciCIQpCvrnzmGoEqQIbIVxpn6VDYlm_SVuq9TU/edit?usp=sharing) 
that specifies what CC is doing in v2 and what it should be doing that has been shared with the community. 
Although effort has been put over time to keep it accurate, it is not 100% a reflection of what V2 really does.

## V3

In v3 API all operations that require broker communication are done asynchronously. This is one of the main differences 
from v2 API. As a result of this approach CF always has a record of the resource that is being created or deleted. 
When the broker operation fails, CF still keeps a record of the resource e.g. if a create binding operation fails the CF
will have keep a record of that resource and set the state to `create failed`. This allows the operator to manually 
remove the failed resource and it means that there should not be any resources that the service broker has created and 
CF does not have a record of.

However, we have chosen to keep performing orphan mitigation in many cases in order to keep some level of consistency 
with the expected behaviour in v2 and to satisfy requirements and issues raised by users.


# Provisioning

## Scenarios when CF will perform OM:

Status code | Response Body |  OSBAPI advices OM |Notes
:------------:| --------------|:--------------:| --------
201 | malformed |  Yes |
202 | malformed | No | If this happens, CF would not be able to record the broker response that might include important properties for continuing the async flow (e.g. operation_id).
2xx | - |  Yes |
422 | unexpected error | No | No resource should have been created, however attempting OM does not have any risks.
5xx | - | Yes |
Client Timeout | - | Yes |

## Scenarios when CF will NOT perform OM:

Status code | Response Body |  OSBAPI advices OM |Notes
:------------:| --------------|:--------------:| --------
200 | Malformed | No |
201 | Other (not malformed) | No |
202 | Other (not malformed) | No |
422 | Requires app/Async/Concurrency error | No |
4xx | - | No |

# Binding
 
## Scenarios when CF will perform OM:

Status code | Response Body |  OSBAPI advices OM |Notes
:------------:| --------------|:--------------:| --------
 200 | bad data | No | If this happens, CF would not be able to record the broker response. Safest assumption is to delete the resource from the broker and allow the operator to start over.
 201 | malformed |  Yes |
 201 | bad data | No | If this happens, CF would not be able to record the broker response. Safest assumption is to delete the resource from the broker and allow the operator to start over.
 202 | malformed | No | If this happens, CF would not be able to record the broker response that might include important properties for continuing the async flow (e.g. operation_id).
 2xx | - |  Yes |
 410 | - | No | This is not a valid error code for a `POST` request. No resource should have been created, however attempting OM does not have any risks.
 422 | unexpected error | No | No resource should have been created, however attempting OM does not have any risks.
 5xx | - | Yes |
 Client Timeout | - | Yes |

## Scenarios when CF will NOT perform OM:

Status code | Response Body |  OSBAPI advices OM |Notes
:------------:| --------------|:--------------:| --------
 200 | Malformed | No |
 201 | Other (not Malformed or Bad data) | No |
 202 | Other (not Malformed or Bad data) | No |
 422 | Requires app/Async/Concurrency error | No |
 4xx | - | No |
 

In v3, in the case of any other CF internal error not related to the Broker response, CF does not perform OM. 
Even in case of failure, there is a record of the resource in the DB and the user is able to delete the resource after failure. 

# Handling service instances and bindings last operation broker responses

Cloud Foundry will not attempt any OM for any of the responses from instances or bindings Last Operation requests. 
We decided to give the operator the possibility of troubleshooting and delete the resource when they see fit, in line with 
[SI behaviour](https://github.com/cloudfoundry/cloud_controller_ng/issues/1842) our users depend on.

## Deprovisioning and Unbinding

In event of failure, Cloud Foundry will keep the record of the resource and the user can attempt to delete again. 
There is not a clear benefit of implementing any OM logic for such straightforward scenario. 

## Changes from v2 to v3
When possible we have kept the same OM implementation in v2 and v3. Cases when we have diverged have been documented in this doc.

In v3 all types of bindings, including service credentials bindings for apps and keys and service route bindings, 
have the same OM behaviour.

# Status
Accepted

# Consequences:
This document is a description of our reasoning about OM and its current implementation at the time of writing. 
The behaviour for each use-case might change if OSBAPI advices new behaviour or our customers request other changes.
