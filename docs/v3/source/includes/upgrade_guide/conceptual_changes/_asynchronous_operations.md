### Asynchronous Operations

Unlike V2, clients cannot opt-in for asynchronous responses from endpoints. Instead, endpoints that require asynchronous processing will return `202 Accepted` with a Location header pointing to the job resource to poll. Endpoints that do not require asynchronous processing will respond synchronously.

For clients that want to report the outcome of an asynchronous operation, poll the job in the Location header until its `state` is no longer `PROCESSING`. If the job's `state` is `FAILED`, the `errors` field will contain any errors that occurred during the operation.

An example of an asynchronous endpoint is the [delete app endpoint](#delete-an-app).

Read more about [the job resource](#jobs).
