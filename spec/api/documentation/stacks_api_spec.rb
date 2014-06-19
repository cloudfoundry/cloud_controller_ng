require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Stacks", type: :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  authenticated_request

  let(:guid) { VCAP::CloudController::Stack.first.guid }

  field :name, "The name for the stack."
  field :description, "The description for the stack"

  standard_model_list(:stack, VCAP::CloudController::StacksController)
  standard_model_get(:stack)
end
