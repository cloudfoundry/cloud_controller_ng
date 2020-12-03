# Context:


The aim of this document is to record how Orphan Mitigation (OM) for bindings is going to be implemented and the reasoning behind the decisions taken.

We define Orphan Mitigation as the attempt(s) made by the platform (Cloud Controller) to clear up any resources that may have been created by a Service Broker during an operation that eventually failed.
In that scenario, two things can happen:
The platform has no record of such resources
The platform still keeps a record

The expectation is that brokers shouldn’t have any resources that the platform does not know about. Therefore OM gains relevance in scenario a) as it is possible the operator ignores such resources may have been created, and there is no way in the platform to list failed operations of resources that are not tracked by it. 
Even if the operator realizes the operation failed, destroying such resources would include direct interaction with the service broker as the platform does not provide tools to delete resources it doesn’t track either.
Scenario b) on the other hand, provides the possibility to choose whether to perform OM or defer the choice to the operator of when to run it.

Consequences of having lingering resources in the broker may include higher costs, resource quota consumption, etc.


## OSB API

As of this document, the Cloud Controller aims to comply with the OSB API 2.15 specification. 
The specification states the platform may choose to leave the decision of when OM happens to the operator in case they need to troubleshoot for any scenario. So whether we perform OM in the scenarios OSBAPI outlines as requiring it or not is our choice, as long as there is another mechanism in the platform the operator can use to perform the orphan mitigation at a later stage (i.e. unbind-service CLI command). We shouldn’t perform OM in the scenarios OSBAPI says it is not needed.

## V2

On the other hand, v2 is not fully compliant with OSB API 2.15 version for OM. Changes needed to be compliant are not backwards compatible so it is difficult to introduce them without releasing a major version. The OM spec changed on OSB API v2.15 and thus, even when v2 was made compatible with that same version, not all scenarios behave the same. Also, in some scenarios the choice was made to give the opportunity to the operator to troubleshoot and not automatically orphan mitigate. In other scenarios the choice was taken not to implement complicated OM logic in places where commands where available to delete resources and so clean up was deferred to the user.

There is also this document that specifies what CC is doing in v2 and what it should be doing that has been shared with the community. Although effort has been put over time to keep it accurate it is not 100% a reflection of what V2 really does.

## V3

In the process of implementing V3, we might have diverged from V2 behavior and some scenarios may have also been invalidated by the fact that endpoints are now asynchronous and we create a resource in the db before even sending a request to the broker.
V3 gives a chance to enforce compatibility being a major redesign of the API. However we need to pay special attention to endpoints that have already been GA’d prior to this document and to users’ requirements and issues raised.


# Decision:



Component     | Status code | Response Body | OM | Comments
--------------| :------------:| --------------|:----:| --------
Service Broker| 200 | malformed | Y |
Service Broker| 201 | malformed | Y |
Service Broker| 201 | bad data | Y | Remote chance of this happening. No complaints. It means we don’t have an accurate record of what the broker has as we are trying to create a binding that already existed on the broker side. So to some extent it makes sense to delete what’s in the broker and allow the operator to start over.
Service Broker| 201 | other | N |
Service Broker| 202 | malformed | Y | We wouldn’t have the operation_id to poll for the last operation status. So We’ll keep v2 behaviour for V3. Consider adding it to OSBAPI spec. We think it was not updated in the spec when operation_id was added to the response.
Service Broker| 202 | other | N |
Service Broker| 2xx | - | Y |
Service Broker| 401 | - | N |
Service Broker| 408 | - | N |
Service Broker| 409 | - | N |
Service Broker| 410 | - | Y | 410 is not a valid error code for a create request. We shouldn’t OM as nothing should have been created but it also doesn’t hurt to keep trying to delete a resource that does not exist. We have also not gotten any issues raised regarding this.<br> We will check how difficult it is to change. But most likely keep it as it is for V2
Service Broker| 422 | Requires app/Async/Concurrency error | N |
Service Broker| 422 | other | Y | The default catch all should be raising ServiceBrokerRequestRejected instead of ServiceBrokerBadRequest. Same as 410 it is not critical. It doesn’t hurt to try to remove something that was not created.
Service Broker| 4xx | - | N |
Service Broker| 5xx | - | Y |
Cloud Controller| Client Timeout | - | Y |
Cloud Controller| Internal error(1) | - | N | We will divert from v2 as we have a record in the database by the time we send the request for the broker. The user can just delete the binding, which will cause a delete request to be sent to the broker as well
Service Broker| Fetching binding details | - | N |


(1) V2 attempts to delete from the broker only once. This is because the assumption is that the DB is down somehow and it won’t be able to persist a Job to keep on trying. The problem that is trying to mitigate is when it has an error saving the binding to the DB, as the flow is Send request To Broker -> save to DB




Component     | Status code | Response Body | OM | Comments
--------------|:-------------:|---------------|:----:| --------
Service Broker| 200 | state:failed | N | We want to give the operator the possibility of troubleshooting and delete the binding (with cf unbind-xxx) when they see fit, in line with [SI behaviour](https://github.com/cloudfoundry/cloud_controller_ng/issues/1842) our users depend on.
Service Broker| 200 | malformed | N |
Service Broker| 200 | other(state:succeeded/in progress) | N |
Service Broker| 400/404/410 | Any | N | 
Cloud Controller| Client Timeout | - | N |
Cloud Controller| Internal error | - | N |
Cloud Controller| Reached max polling interval | - | N | 

All other codes mean keep polling, so no need for any error handling.



## Unbinding

V2 doesn’t do OM in any unbinding scenarios (including last operation polling failures).

OSBAPI specifies the same behaviour for binding requests however, it also says:
“Responses with any other status code MUST be interpreted as a failure and the Platform MUST continue to remember the Service Binding.” by other being other than 200, 202, 400, 410, 422 in an unbind operation.
Which can be interpreted as no OM needs to be done


V3 will keep V2’s approach, as we will still have the record in the Cloud Controller database and the operator can still try to delete again. There doesn’t seem to be a clear benefit of implementing complicated OM logic for such straightforward scenario. 

We will consider implementing the SI approach of retrying the delete one more time, although it won’t be a priority for us unless it is required by the community.


## Service keys
Service keys have almost the same behaviour than that of service bindings. As the code lies in different client methods some fixes done to bindings have not made their way to service keys. We will bring service keys to parity. All specs coincide with service keys and bindings having the same OM behaviour
For that we need to avoid performing OM for a 200 response with a malformed body.


# Status
Draft

# Consequences:

We are mostly keeping in line with what v2 does, except for the scenarios that do not happen in v3 and the places where the code is significantly simpler and easier to maintain if we moved closer to OSB API. 
As a consequence we might get issues filed regarding misalignment with the spec. However the spec is quite loose and we have good justification for the scenarios we are deviating from it; Hence we are confident this won’t cause future problems.

