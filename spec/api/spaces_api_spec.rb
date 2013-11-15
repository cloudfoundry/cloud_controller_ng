require "spec_helper"
require "rspec_api_documentation/dsl"

resource "Spaces", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  let(:guid) { VCAP::CloudController::Space.first.guid }
  let!(:spaces) { 3.times { VCAP::CloudController::Space.make } }

  authenticated_request
  standard_parameters VCAP::CloudController::SpacesController

  field :guid, "The guid of the space.", required: false
  field :name, "The name of the space", required: true, example_values: %w(development demo production)
  field :organization_guid, "The guid of the associated organization", required: true, example_values: [VCAP::CloudController::Organization.make.guid]
  field :developer_guids, "The list of the associated developers", required: false
  field :manager_guids, "The list of the associated managers", required: false
  field :auditor_guids, "The list of the associated auditors", required: false
  field :domain_guids, "The list of the associated domains", required: false

  standard_model_list :space
  standard_model_get :space
  standard_model_delete :space

  def after_standard_model_delete(guid)
    event = VCAP::CloudController::Event.find(type: "audit.space.delete-request", actee: guid)
    audited_event event
  end

  post "/v2/spaces/" do
    example "Creating a space" do
      client.post "/v2/spaces", fields_json, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :space

      space_guid = parsed_response['metadata']['guid']
      audited_event VCAP::CloudController::Event.find(type: "audit.space.create", actee: space_guid)
    end
  end

  put "/v2/spaces/:guid" do
    let(:new_name) { "New Space Name" }

    example "Update a space" do
      client.put "/v2/spaces/#{guid}", Yajl::Encoder.encode({ "name" => new_name }), headers
      expect(status).to eq 201
      standard_entity_response parsed_response, :space, name: new_name

      audited_event VCAP::CloudController::Event.find(type: "audit.space.update", actee: guid)
    end
  end
end
