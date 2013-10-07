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

  field :default_space_guid, "The guid of the default space for apps created by this user.", required: true

  field :admin, "Whether the user is an admin (Use UAA instead).", required: false, deprecated: true
  field :default_space_url, "The url of the default space for apps created by the user.", required: false, readonly: true
  field :spaces_url, "The url of the spaces this user is a member of.", required: false, readonly: true
  field :organizations_url, "The url of the organizations this user in a member of.", required: false, readonly: true
  field :managed_organizations_url, "The url of the organizations this user in a manager of.", required: false, readonly: true
  field :billing_managed_organizations_url, "The url of the organizations this user in a billing manager of.", required: false, readonly: true
  field :audited_organizations_url, "The url of the organizations this user in a auditor of.", required: false, readonly: true
  field :managed_spaces_url, "The url of the spaces this user in a manager of.", required: false, readonly: true
  field :audited_spaces_url, "The url of the spaces this user in a auditor of.", required: false, readonly: true

  standard_model_object :user # adds get /v2/users/ and get /v2/users/:guid

  put "/v2/users/:guid" do
      request_parameter :guid, "The guid for the user to alter"

      let(:default_space_guid) { space.guid }

      example "Update a User's default space" do
        client.put "/v2/users/#{guid}", Yajl::Encoder.encode(params), headers
        status.should == 201
        space.guid.should_not be_nil
        standard_entity_response parsed_response, :user, :default_space_guid => space.guid
      end
  end
end
