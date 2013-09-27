require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Users", :type => :api do

  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  before do
    3.times { VCAP::CloudController::User.make }
  end

  let(:guid) { VCAP::CloudController::User.first.guid }
  let(:space) { VCAP::CloudController::Space.make }

  standard_parameters
  response_fields_from_table :user
  standard_model_object :user # adds get /v2/users/ and get /v2/users/:guid

  put "/v2/users/:guid" do
      let(:default_space_guid) { space.guid }

      example "Update a User's default space" do
        client.put "/v2/users/#{guid}", Yajl::Encoder.encode(params), headers
        status.should == 201
        space.guid.should_not be_nil
        standard_entity_response parsed_response, :user, :default_space_guid => space.guid
      end
  end
end
