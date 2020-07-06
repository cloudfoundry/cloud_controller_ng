# Context:
In V2, we attempted to have every error from any component of a cloud foundry deployment (~262 errors) in a single YAML file with strict pre-written messages. Due to the overwhelming number of errors, seemingly arbitrary error codes, and inflexible messages, neither clients nor developers were wholly pleased.

In V3, in order to improve on message flexibility, we switched to using error types that were specific to the module they are created in, and translate them all into generic API Errors (422 Unprocessable Entity, see figure 1) at the controller level. This, in theory, gave us the benefit of knowing the most possible amount of context before creating custom error messages.

```
422 Unprocessable Entity
{
       "detail": "Relationships is not a hash.",
       "title": "CF-UnprocessableEntity",
       "code": 10008
}
```
*Figure 1: Currently Cloud Foundry API presents errors in a JSON-encoded string with three fields: detail, title, and code.*

However, clients now typically use the detail field to determine the exact type of error. This can be a pain for clients. For example, the CloudFoundry CLI is forced to have complicated branching logic (see figure 6) to catch and interpret CAPI errors messages in order to be able to type check on errors. This code has drawbacks: the detail field is a free-form string, and thus is brittle. If CAPI wanted to change their error messages for product reasons, this could potentially break CLI code paths.

Our aim is to retain helpful and context specific error messages, while also providing additional lower context, high level information that directly applies to client needs. 

# Decision:
We propose making greater use of the code and title field in the error. We will break out commonly used umbrella categorizations of errors into new classes of errors with different titles and codes, while maintaining their customized error messages. 

For example, a common workflow in the CLI is swallowing CAPI uniqueness constraint errors on create actions to maintain idempotent behavior. Instead of searching for the unique error string that CAPI returns for each resource, as the CLI currently does, we would match on a more generic CAPI error such as figure 2.

```
422 Unprocessable Entity
{
       "detail": "custom error message.",
       "title": "NotUniqueError",
       "code": x
}
```
*Figure 2: This error is a new error sub class of the 422 HTTP status error. The title and code would give a client high level information about what caused the error, while the detail would still be a custom string that is flexible to product needs, and could in many cases be returned directly to a user.*

## Implementation
The majority of these errors are triggered by the Model-validation. A typical example is shown in figure 3.

```
def create(message, organization:) 
    # redacted
rescue Sequel::ValidationFailed => e
    validation_error!(e, message)
end
```
```
def validation_error!(error, message)
    if error.errors.on([:organization_id, :name])&.include?(:unique)
        error!("Space Quota '#{message.name}' already exists.")
    end
    error!(error.message)
end
```
*Figure 3: full code snippet can be found [here](https://github.com/cloudfoundry/cloud_controller_ng/blob/ef1a2df185aed77ea657c6015f9d457e353449b9/app/actions/space_quotas_create.rb#L6-L44)*

Then this error is converted to our usual `CF-UnprocessableEntity` error in figure 4.

```
def create
    # redacted.
    space_quota = SpaceQuotasCreate.new.create(message, organization: org)
    render status: :created, json: Presenters::V3::SpaceQuotaPresenter.new(
      space_quota,
      visible_space_guids: permission_queryer.readable_space_guids
    )
rescue SpaceQuotasCreate::Error => e
    unprocessable!(e.message)
end
```
*Figure 4: full code snippet can be found [here](https://github.com/cloudfoundry/cloud_controller_ng/blob/ef1a2df185aed77ea657c6015f9d457e353449b9/app/controllers/v3/space_quotas_controller.rb#L14-L31)*

In our proposal, we raise our new class of error in `CloudController::SpaceQuotasCreate` and return it directly to the user (figure 5).

```
def validation_error!(error, message)
    if error.errors.on([:organization_id, :name])&.include?(:unique)
        CloudController::Errors::ApiError.new_from_details('NotUniqueError', "Space Quota name must be unique in organization")
    end
    error!(error.message)
end
```
```
def create
     # redacted.
     space_quota = SpaceQuotasCreate.new.create(message, organization: org)
     render status: :created, json: Presenters::V3::SpaceQuotaPresenter.new(
       space_quota,
       visible_space_guids: permission_queryer.readable_space_guids
    )
rescue SpaceQuotasCreate::Error => e
    unprocessable!(e.message) 
end
```
*Figure 5: Note that the function `error` defined in `validation_error!` returns an error of type `Error` scoped to the module `SpaceQuotasCreate`- the same type that we are rescuing in the controller. By changing the type of the error raised in the action to the desired type, we can return the error directly to the client.*

In this example, the final message string is already set in the action, so we will not lose anything by also defining the type there as well. Our aim is not to define every possible type of error as its own class; doing so might encourage future developers to reuse errors or create errors that might not have the most detailed information. In some cases, it might be better to leave information a client needs in the detail string if it breaks patterns in a dangerous way. Maintaining the patterns and structure of the API is also a priority. Our aim is to find commonly used logical units of errors that are simple to separate. As a first iteration, we plan to extract errors to condense the error branching in the V7 CLI as much as possible. We can break out further cases as needed based on future requests and user feedback. 

# Status
Accepted

# Consequences:

## Benefits:
This would benefit to Clients such as the CLI which have resorted to large (11+) case statements to untangle the type of error (see figure 6).

```
case strings.Contains(errorString,
		"Route already exists"):
		return ccerror.RouteNotUniqueError{UnprocessableEntityError: err}
```
*Figure 6: full case statement [here](https://github.com/cloudfoundry/cli/blob/ea2b61d623157647a6fbb35f63b16549fce68151/api/cloudcontroller/ccv3/errors.go#L141-L178)*

The 7 different checks for not-unique errors would be replaced by a single check, making the code simpler to understand and more robust:

```
case errorResponse.Code == x:
		return ccerror.NotUniqueError{}
```

## Concerns:
* There is a potential to create API Errors specialized to the places that they are thrown, rather than at the highest level. We will have to be careful not to be too liberal with this pattern and might end up with some inconsistency around how we throw errors (i.e throwing an API error directly in the action for the uniqueness validation constraint case, while rescuing a generic SpaceQuotaCreate::Error for all other cases in the example).
* Error umbrellas might be ambiguous. It might be unclear which umbrella a future error would be placed under, and we would not have much flexibility to restructure after entering error types into our contracts with clients.
* It is unclear if existing clients are dependent on the the `CF-UnprocessableEntity` error structure existing the way it does.
