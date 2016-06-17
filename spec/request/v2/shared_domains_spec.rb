require 'spec_helper'

RSpec.describe 'SharedDomains' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)

    stub_request(:post, 'http://routing-client:routing-secret@localhost:8080/uaa/oauth/token').
      with(body: 'grant_type=client_credentials').
      to_return(status: 200,
                body:           '{"token_type": "monkeys", "access_token": "banana"}',
                headers:        { 'content-type' => 'application/json' })

    stub_request(:get, 'http://localhost:3000/routing/v1/router_groups').
      to_return(status: 200, body: '{}', headers: {})
  end

  describe 'GET /v2/shared_domains' do
    let!(:domain) { VCAP::CloudController::SharedDomain.make(name: 'my-domain.edu', router_group_guid: 'tcp-group') }

    it 'lists all shared domains' do
      get '/v2/shared_domains', nil, headers_for(user)

      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 3,
          'total_pages'   => 1,
          'prev_url'      => nil,
          'next_url'      => nil,
          'resources'     => [
            {
              'metadata' => {
                'guid'       => /\w+/,
                'url'        => %r{/v2/shared_domains/},
                'created_at' => iso8601,
                'updated_at' => nil
              },
              'entity' => {
                'name'              => 'customer-app-domain1.com',
                'router_group_guid' => nil,
                'router_group_type' => nil
              }
            },
            {
              'metadata' => {
                'guid'       => /\w+/,
                'url'        => %r{/v2/shared_domains/},
                'created_at' => iso8601,
                'updated_at' => nil
              },
              'entity' => {
                'name'              => 'customer-app-domain2.com',
                'router_group_guid' => nil,
                'router_group_type' => nil
              }
            },
            {
              'metadata' => {
                'guid'       => domain.guid,
                'url'        => "/v2/shared_domains/#{domain.guid}",
                'created_at' => iso8601,
                'updated_at' => nil
              },
              'entity' => {
                'name'              => domain.name,
                'router_group_guid' => 'tcp-group',
                'router_group_type' => nil
              }
            },
          ]
        }
      )
    end
  end

  describe 'GET /v2/shared_domains/:guid' do
    let!(:domain) { VCAP::CloudController::SharedDomain.make(router_group_guid: 'tcp-group') }

    it 'shows the shared domain' do
      get "/v2/shared_domains/#{domain.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => domain.guid,
            'url'        => "/v2/shared_domains/#{domain.guid}",
            'created_at' => iso8601,
            'updated_at' => nil
          },
          'entity' => {
            'name'              => domain.name,
            'router_group_guid' => 'tcp-group',
            'router_group_type' => nil
          }
        }
      )
    end
  end

  describe 'POST /v2/shared_domains' do
    it 'makes a shared domain' do
      post '/v2/shared_domains', '{"name": "meow.mc.meowerson.com"}', admin_headers_for(user)

      expect(last_response.status).to be(201)

      domain = VCAP::CloudController::SharedDomain.last

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
        'metadata' => {
          'guid'       => domain.guid,
          'url'        => "/v2/shared_domains/#{domain.guid}",
          'created_at' => iso8601,
          'updated_at' => nil
        },
        'entity' => {
          'name'              => 'meow.mc.meowerson.com',
          'router_group_guid' => nil,
          'router_group_type' => nil
        }
      })
    end
  end

  describe 'PUT /v2/shared_domains/:guid' do
    let!(:domain) { VCAP::CloudController::SharedDomain.make(name: 'my-domain.edu', router_group_guid: 'tcp-group') }

    it 'ignores everything and returns the original object, suckers!' do
      put "/v2/shared_domains/#{domain.guid}", '{"name": "meow.com", "route_group_guid": "a-guid"}', admin_headers_for(user)

      expect(last_response.status).to eq(201)
      parsed_response = MultiJson.load(last_response.body)

      expect(parsed_response).to be_a_response_like({
        'metadata' => {
          'guid'       => domain.guid,
          'url'        => "/v2/shared_domains/#{domain.guid}",
          'created_at' => iso8601,
          'updated_at' => iso8601
        },
        'entity' => {
          'name'              => 'my-domain.edu',
          'router_group_guid' => 'tcp-group',
          'router_group_type' => nil
        }
      })
    end
  end

  describe 'DELETE /v2/shared_domains/:guid' do
    let!(:domain) { VCAP::CloudController::SharedDomain.make(name: 'my-domain.edu', router_group_guid: 'tcp-group') }

    it 'deletes the shared_domain' do
      delete "/v2/shared_domains/#{domain.guid}", nil, admin_headers_for(user)
      expect(last_response.status).to be(204)
      expect(last_response.body).to eq('')
    end
  end
end
