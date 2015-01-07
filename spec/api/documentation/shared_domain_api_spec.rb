require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Shared Domains', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:guid) { VCAP::CloudController::SharedDomain.first.guid }
  let!(:domains) { 3.times { VCAP::CloudController::SharedDomain.make } }

  authenticated_request

  field :guid, 'The guid of the domain.', required: false
  field :name, 'The name of the domain.', required: true, example_values: ['example.com', 'foo.example.com']

  standard_model_list :shared_domain, VCAP::CloudController::SharedDomainsController
  standard_model_get :shared_domain
  standard_model_delete :shared_domain

  post '/v2/shared_domains' do
    example 'Create a Shared Domain' do
      client.post '/v2/shared_domains', fields_json, headers
      expect(status).to eq 201
      standard_entity_response parsed_response, :shared_domain,
                               name: 'example.com'
    end
  end

  get '/v2/shared_domains' do
    standard_list_parameters VCAP::CloudController::SharedDomainsController

    describe 'Querying Shared Domains by name' do
      let(:q) { 'name:shared-domain.com' }

      before do
        VCAP::CloudController::SharedDomain.make name: 'shared-domain.com'
      end

      example 'Filtering Shared Domains by name' do
        client.get '/v2/shared_domains', params, headers

        expect(status).to eq(200)

        standard_paginated_response_format? parsed_response

        expect(parsed_response['resources'].size).to eq(1)

        standard_entity_response(
          parsed_response['resources'].first,
          :shared_domain,
          name: 'shared-domain.com')
      end
    end
  end
end
