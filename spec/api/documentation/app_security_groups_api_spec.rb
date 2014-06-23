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

  shared_context "guid_parameter" do
    parameter :guid, "The guid of the App Security Group"
  end

  shared_context "updatable_fields" do
    field :name, "The name of the app security group.", required: true, example_values: ["my_super_app_sec_group"]
    field :rules, "The egress rules for apps that belong to this app security group.", default: [],
      example_values: [[
        {protocol: "icmp", destination: "0.0.0.0/0", type: 0, code: 1},
        {protocol: "tcp", destination: "0.0.0.0/0", ports: "2048-3000"},
        {protocol: "udp", destination: "0.0.0.0/0", ports: "53, 5353"},
        ]]
    field :space_guids, "The list of associated spaces.", default: []
  end

  describe "Standard endpoints" do
    standard_model_list :app_security_group, VCAP::CloudController::AppSecurityGroupsController
    standard_model_get :app_security_group
    standard_model_delete :app_security_group

    post "/v2/app_security_groups/" do
      include_context "updatable_fields"
      example "Creating an App Security Group" do
        client.post "/v2/app_security_groups", fields_json({rules: field_data("rules")[:example_values].first}), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :app_security_group
      end
    end

    put "/v2/app_security_groups/:guid" do
      include_context "guid_parameter"
      include_context "updatable_fields"
      modify_fields_for_update
      example "Updating an App Security Group" do
        new_security_group = {name: 'new_name', rules: []}

        client.put "/v2/app_security_groups/#{guid}", Yajl::Encoder.encode(new_security_group), headers
        status.should == 201
        standard_entity_response parsed_response, :app_security_group, name: 'new_name', rules: []
      end
    end
  end

  describe "Nested endpoints" do
    include_context "guid_parameter"
    describe "Spaces" do
      before do
        app_security_group.add_space associated_space
      end
      let!(:associated_space) { VCAP::CloudController::Space.make }
      let(:associated_space_guid) { associated_space.guid }
      let(:space) { VCAP::CloudController::Space.make }
      let(:space_guid) { space.guid }

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :app_security_group
      describe "with space_guid" do
        parameter :space_guid, "The guid of the Space"
        nested_model_associate :space, :app_security_group
        nested_model_remove :space, :app_security_group
      end
    end
  end
end
