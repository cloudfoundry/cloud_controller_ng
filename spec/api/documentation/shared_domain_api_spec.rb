require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Shared Domains', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:guid) { VCAP::CloudController::SharedDomain.first.guid }
  let!(:domains) { 3.times { VCAP::CloudController::SharedDomain.make } }
  let!(:tcp_domains) { 1.times { VCAP::CloudController::SharedDomain.make router_group_guid: 'my-random-guid' } }

  authenticated_request

  standard_model_list :shared_domain, VCAP::CloudController::SharedDomainsController
  standard_model_get :shared_domain
  standard_model_delete :shared_domain

  let(:routing_api_body) do
    [
      { guid: 'router-group-guid1', name: 'group-name', type: 'tcp' },
      { guid: 'my-random-guid', name: 'group-name', type: 'tcp' }
    ].to_json
  end
  let(:routing_api_url) do
    url = TestConfig.config[:routing_api][:url]
    "#{url}/routing/v1/router_groups"
  end

  before do
    allow_any_instance_of(CF::UAA::TokenIssuer).to receive(:client_credentials_grant).
      and_return(double('token_info', auth_header: 'bearer AUTH_HEADER'))

    stub_request(:get, routing_api_url).
      with(headers: { 'Authorization' => 'bearer AUTH_HEADER' }).
      to_return(status: 200, body: routing_api_body)
  end

  post '/v2/shared_domains' do
    field :name, 'The name of the domain.', required: true, example_values: ['example.com', 'foo.example.com']
    field :router_group_guid, 'The guid of the router group.', required: false, experimental: true

    example 'Create a Shared Domain' do
      client.post '/v2/shared_domains', fields_json(router_group_guid: 'my-random-guid'), headers

      expect(status).to eq 201
      standard_entity_response parsed_response, :shared_domain,
                               name: 'example.com', router_group_guid: 'my-random-guid'

      domain_guid = parsed_response['metadata']['guid']
      domain = VCAP::CloudController::Domain.find(guid: domain_guid)
      expect(domain.router_group_guid).to eq('my-random-guid')
    end
  end

  get '/v2/shared_domains' do
    standard_list_parameters VCAP::CloudController::SharedDomainsController

    describe 'Querying Shared Domains by name' do
      let(:q) { 'name:shared-domain.com' }

      before do
        VCAP::CloudController::SharedDomain.make name: 'shared-domain.com', router_group_guid: 'my-random-guid'
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
