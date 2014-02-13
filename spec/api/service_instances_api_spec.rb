require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Service Instances", type: :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  field :guid, "The guid of the service instance", required: true

  let(:instance) { VCAP::CloudController::ServiceInstance.make }
  let(:guid) { instance.guid }

  get "/v2/service_instances/:guid/permissions" do
    example "Retrieving permissions on a service instance" do
      client.get "/v2/service_instances/#{guid}/permissions", {}, headers
      expect(status).to eq(200)

      expect(parsed_response).to eql({ 'manage' => true })
    end
  end
end
