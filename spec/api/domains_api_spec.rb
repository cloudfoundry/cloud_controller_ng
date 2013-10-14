require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Domains", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  before do
    reset_database

    3.times do
      VCAP::CloudController::Domain.make
    end
  end

  let(:guid) { VCAP::CloudController::Domain.first.guid }

  standard_parameters

  field :name, "The name of the domain.",
        required: true, example_values: ["example.com", "foo.example.com"]
  field :wildcard, "Whether the domain supports routes with empty hosts",
        required: true
  field :owning_organization_guid, "The organization that owns the domain. If not specified, the domain is shared.",
        required: false

  standard_model_object :domain

  post "/v2/domains" do
    let(:name) { "exmaple.com" }
    let(:wildcard) { true }

    context "without a owning organization" do
      let(:owning_organization_guid) { nil }

      example "creates a shared domain" do
        client.post "/v2/domains", Yajl::Encoder.encode(params), headers
        status.should == 201
        standard_entity_response parsed_response, :domain,
                                 :name => name,
                                 :owning_organization_guid => nil
      end
    end

    context "with an owning organization" do
      let(:owning_organization) { VCAP::CloudController::Organization.make }
      let(:owning_organization_guid) { owning_organization.guid }

      example "creates a domain owned by the given organization" do
        client.post "/v2/domains", Yajl::Encoder.encode(params), headers
        status.should == 201
        standard_entity_response parsed_response, :domain,
                                 :name => name,
                                 :owning_organization_guid => owning_organization.guid
      end
    end
  end
end
