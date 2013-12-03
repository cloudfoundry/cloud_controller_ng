require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Shared Domains", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  let(:guid) { VCAP::CloudController::SharedDomain.first.guid }
  let!(:domains) { 3.times { VCAP::CloudController::SharedDomain.make } }

  authenticated_request
  standard_parameters VCAP::CloudController::SharedDomainsController

  field :guid, "The guid of the domain.", required: false
  field :name, "The name of the domain.", required: true, example_values: ["example.com", "foo.example.com"]

  standard_model_list(:shared_domain)
  standard_model_get(:shared_domain)
  standard_model_delete(:shared_domain)

  post "/v2/shared_domains" do
    example "Create a shared domain" do
      client.post "/v2/shared_domains", fields_json, headers
      expect(status).to eq 201
      standard_entity_response parsed_response, :shared_domain,
                               name: "example.com"
    end
  end
end
