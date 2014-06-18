require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "App Security Groups (experimental)", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let(:app_security_group) { VCAP::CloudController::AppSecurityGroup.first }
  let(:guid) { app_security_group.guid }
  before do
    3.times { VCAP::CloudController::AppSecurityGroup.make }
  end

  authenticated_request

  field :name, "The name of the app security group.", required: true, example_values: ["my_super_app_sec_group"]
  field :rules, "The egress rules for apps that belong to this app security group.", required: false
  field :space_guids, "The list of associated spaces.", required: false

  standard_model_list :app_security_group, VCAP::CloudController::AppSecurityGroupsController
  standard_model_get :app_security_group
  standard_model_delete :app_security_group

  post "/v2/app_security_groups/" do
    example "Creating an App Security Group" do
      client.post "/v2/app_security_groups", Yajl::Encoder.encode(required_fields), headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :app_security_group
    end
  end

  put "/v2/app_security_groups/:guid" do
    example "Updating an App Security Group" do
      new_attributes = {name: 'new_name', rules: '[]'}

      client.put "/v2/app_security_groups/#{guid}", Yajl::Encoder.encode(new_attributes), headers
      status.should == 201
      standard_entity_response parsed_response, :app_security_group, name: 'new_name', rules: '[]'
    end
  end

  get "/v2/app_security_groups/:guid/spaces" do
    example "List all Spaces associated with an App Security Group" do
      space = VCAP::CloudController::Space.make
      app_security_group.add_space space

      client.get "/v2/app_security_groups/#{guid}/spaces", "", headers
      status.should == 200
      standard_list_response parsed_response, :space
    end
  end
end
