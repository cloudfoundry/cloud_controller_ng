require 'spec_helper'

RSpec.describe 'PrivateDomains' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
  let(:organization) { space.organization }

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

  describe 'GET /v2/private_domains' do
    let!(:domain) { VCAP::CloudController::PrivateDomain.make(name: 'my-domain.edu', router_group_guid: 'tcp-group', owning_organization: organization) }

    it 'lists all private domains' do
      get '/v2/private_domains', nil, headers_for(user)

      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages'   => 1,
          'prev_url'      => nil,
          'next_url'      => nil,
          'resources'     => [
            {
              'metadata' => {
                'guid'       => domain.guid,
                'url'        => "/v2/private_domains/#{domain.guid}",
                'created_at' => iso8601,
                'updated_at' => nil
              },
              'entity' => {
                'name' => domain.name,
                'owning_organization_guid' => organization.guid,
                'owning_organization_url' => "/v2/organizations/#{organization.guid}",
                'shared_organizations_url' => "/v2/private_domains/#{domain.guid}/shared_organizations",
              }
            },
          ]
        }
      )
    end
  end

  describe 'GET /v2/private_domains/:guid' do
    let!(:domain) { VCAP::CloudController::PrivateDomain.make(router_group_guid: 'tcp-group', owning_organization: organization) }

    it 'shows the private domain' do
      get "/v2/private_domains/#{domain.guid}", nil, admin_headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => domain.guid,
            'url'        => "/v2/private_domains/#{domain.guid}",
            'created_at' => iso8601,
            'updated_at' => nil
          },
          'entity' => {
            'name' => domain.name,
            'owning_organization_guid' => organization.guid,
            'owning_organization_url' => "/v2/organizations/#{organization.guid}",
            'shared_organizations_url' => "/v2/private_domains/#{domain.guid}/shared_organizations",
          }
        }
      )
    end
  end

  describe 'POST /v2/private_domains' do
    it 'makes a private domain' do
      post '/v2/private_domains', "{\"name\": \"meow.mc.meowerson.com\", \"owning_organization_guid\": \"#{organization.guid}\"", admin_headers_for(user)

      expect(last_response.status).to be(201)

      domain = VCAP::CloudController::PrivateDomain.last

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
        'metadata' => {
          'guid'       => domain.guid,
          'url'        => "/v2/private_domains/#{domain.guid}",
          'created_at' => iso8601,
          'updated_at' => nil
        },
        'entity' => {
          'name' => 'meow.mc.meowerson.com',
          'owning_organization_guid' => organization.guid,
          'owning_organization_url' => "/v2/organizations/#{organization.guid}",
          'shared_organizations_url' => "/v2/private_domains/#{domain.guid}/shared_organizations",
        }
      })
    end
  end

  describe 'PUT /v2/private_domains/:guid' do
    let!(:domain) { VCAP::CloudController::PrivateDomain.make(name: 'my-domain.edu', router_group_guid: 'tcp-group', owning_organization: organization) }

    it 'updates the private domain' do
      put "/v2/private_domains/#{domain.guid}", '{"name": "meow.com"}', admin_headers_for(user)

      expect(last_response.status).to eq(201)
      parsed_response = MultiJson.load(last_response.body)

      expect(parsed_response).to be_a_response_like({
        'metadata' => {
          'guid'       => domain.guid,
          'url'        => "/v2/private_domains/#{domain.guid}",
          'created_at' => iso8601,
          'updated_at' => iso8601
        },
        'entity' => {
          'name' => 'meow.com',
          'owning_organization_guid' => organization.guid,
          'owning_organization_url' => "/v2/organizations/#{organization.guid}",
          'shared_organizations_url' => "/v2/private_domains/#{domain.guid}/shared_organizations",
        }
      })
    end
  end

  describe 'DELETE /v2/private_domains/:guid' do
    let!(:domain) { VCAP::CloudController::PrivateDomain.make(name: 'my-domain.edu', router_group_guid: 'tcp-group', owning_organization: organization) }

    it 'deletes the private domain' do
      delete "/v2/private_domains/#{domain.guid}", nil, admin_headers_for(user)
      expect(last_response.status).to be(204)
      expect(last_response.body).to eq('')
    end
  end
end
