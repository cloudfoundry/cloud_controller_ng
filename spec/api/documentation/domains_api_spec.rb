require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Domains (deprecated)', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let!(:domain) { VCAP::CloudController::SharedDomain.make }
  let(:guid) { domain.guid }

  authenticated_request

  describe 'Standard endpoints' do
    field :guid, 'The guid of the domain.', required: false
    field :name, 'The name of the domain.', required: true, example_values: ['example.com', 'foo.example.com']
    field :wildcard, 'Allow routes with non-empty hosts', required: true, valid_values: [true, false]
    field :owning_organization_guid, 'The organization that owns the domain. If not specified, the domain is shared.', required: false

    standard_model_list(:shared_domain, VCAP::CloudController::DomainsController, path: :domain)
    standard_model_get(:shared_domain, path: :domain)
    standard_model_delete(:domain)

    post '/v2/domains' do
      context 'Creating a shared domain' do
        example 'creates a shared domain' do
          client.post '/v2/domains', fields_json, headers
          expect(status).to eq 201
          standard_entity_response parsed_response, :domain,
                                   name: 'example.com',
                                   owning_organization_guid: nil
        end
      end

      context 'Creating a domain owned by an organization' do
        example 'creates a domain owned by the given organization' do
          org_guid = VCAP::CloudController::Organization.make.guid
          payload = MultiJson.dump(
            {
              name:                     'exmaple.com',
              wildcard:                 true,
              owning_organization_guid: org_guid
            }, pretty: true)

          client.post '/v2/domains', payload, headers

          expect(status).to eq 201
          standard_entity_response parsed_response, :domain,
                                   name: 'exmaple.com',
                                   owning_organization_guid: org_guid
        end
      end
    end
  end

  describe 'Nested endpoints' do
    field :guid, 'The guid of the Domain', required: true

    describe 'Spaces' do
      let!(:domain) { VCAP::CloudController::PrivateDomain.make }
      before do
        VCAP::CloudController::Space.make(organization: domain.owning_organization)
      end

      standard_model_list :space, VCAP::CloudController::SpacesController, outer_model: :domain
    end
  end
end
