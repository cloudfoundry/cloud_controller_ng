require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Apps", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  before do
    3.times do
      VCAP::CloudController::App.make
    end
  end

  let(:guid) { VCAP::CloudController::App.first.guid }

  standard_parameters
  response_fields_from_table :app
  standard_model_object :app # adds get /v2/users/ and get /v2/users/:guid
end
