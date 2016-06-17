require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Private Domains', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:guid) { VCAP::CloudController::PrivateDomain.first.guid }
  let!(:domains) { 3.times { VCAP::CloudController::PrivateDomain.make } }

  authenticated_request

  shared_context 'guid_parameter' do
    parameter :guid, 'The guid of the domain'
  end

  describe 'Standard endpoints' do
    shared_context 'updatable_fields' do
      field :name, 'The name of the domain.', required: true, example_values: ['example.com', 'foo.example.com']
      field :owning_organization_guid, 'The organization that owns the domain.', required: true
    end

    standard_model_list :private_domain, VCAP::CloudController::PrivateDomainsController
    standard_model_get :private_domain, nested_associations: [:owning_organization]
    standard_model_delete :private_domain

    post '/v2/private_domains' do
      include_context 'updatable_fields'
      example 'Create a Private Domain owned by the given Organization' do
        org_guid = VCAP::CloudController::Organization.make.guid
        payload = MultiJson.dump(
          {
            name:                     'exmaple.com',
            owning_organization_guid: org_guid,
          }, pretty: true)

        client.post '/v2/private_domains', payload, headers

        expect(status).to eq 201
        standard_entity_response parsed_response, :private_domain,
                                 name: 'exmaple.com',
                                 owning_organization_guid: org_guid
      end
    end

    get '/v2/private_domains' do
      standard_list_parameters VCAP::CloudController::PrivateDomainsController

      describe 'querying by name' do
        let(:q) { 'name:my-domain.com' }

        before do
          VCAP::CloudController::PrivateDomain.make name: 'my-domain.com'
        end

        example 'Filtering Private Domains by name' do
          client.get '/v2/private_domains', params, headers

          expect(status).to eq(200)

          standard_paginated_response_format? parsed_response

          expect(parsed_response['resources'].size).to eq(1)

          standard_entity_response(
            parsed_response['resources'].first,
            :private_domain,
            name: 'my-domain.com')
        end
      end
    end
  end

  describe 'Nested endpoints' do
    include_context 'guid_parameter'

    describe 'Shared Organizations' do
      before do
        pd = VCAP::CloudController::PrivateDomain[guid: guid]
        org = VCAP::CloudController::Organization.make
        org.add_private_domain(pd)
      end

      standard_model_list :organization, VCAP::CloudController::OrganizationsController, outer_model: :private_domain, path: :shared_organizations
    end
  end
end
