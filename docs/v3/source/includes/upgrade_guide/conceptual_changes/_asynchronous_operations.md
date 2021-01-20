### Asynchronous Operations

Unlike V2, clients cannot opt-in for asynchronous responses from endpoints. 
Instead, endpoints that require asynchronous processing will return `202 Accepted` with a Location header pointing to the job resource to poll. 
Endpoints that do not require asynchronous processing will respond synchronously.

For clients that want to report the outcome of an asynchronous operation, poll the job in the Location header until its `state` is no longer `PROCESSING`. 
If the job's `state` is `FAILED`, the `errors` field will contain any errors that occurred during the operation.

An example of an asynchronous endpoint is the [delete app endpoint](#delete-an-app).

Service related endpoints such as [service instance](#service-instances), [service credential binding](#service-credential-binding) and [service route binding](#service-route-binding) may create jobs 
that transition to state `POLLING` after `PROCESSING`. This state reflects the polling of the last operation from the service broker.
For clients that want to report the outcome of this asynchronous operation, poll the job in the Location header until its `state` is no longer `POLLING`.

Read more about [the job resource](#jobs).
