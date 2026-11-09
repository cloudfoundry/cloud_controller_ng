require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Service account route sources' do
    it 'refuses account rules until qualified routers are explicitly enabled' do
      org = create(:organization, service_account_prefix: 'route-team')
      space = create(:space, organization: org)
      ServiceAccountModel.create(name: 'route-worker', space: space)
      domain = create(:private_domain, owning_organization: org, enforce_route_policies: true)
      route = create(:route, space: space, domain: domain)
      body = { source: 'cf:svc:route-team:route-worker', relationships: { route: { data: { guid: route.guid } } } }
      post '/v3/route_policies', body.to_json, admin_headers_for(create(:user))
      expect(last_response.status).to eq(422)
      expect(parsed_response.dig('errors', 0, 'detail')).to include('router contract')
    end

    it 'rejects granting an unreadable account and filters qualified sources without parser failures' do
      TestConfig.override(service_account_router_contract_version: 2)
      org = create(:organization, service_account_prefix: 'route-team')
      space = create(:space, organization: org)
      hidden_space = create(:space, organization: create(:organization, service_account_prefix: 'hidden-team'))
      ServiceAccountModel.create(name: 'hidden-worker', space: hidden_space)
      domain = create(:private_domain, owning_organization: org, enforce_route_policies: true)
      route = create(:route, space: space, domain: domain)
      user = create(:user)
      headers = set_user_with_header_as_role(role: 'space_developer', org: org, space: space, user: user)
      body = { source: 'cf:svc:hidden-team:hidden-worker', relationships: { route: { data: { guid: route.guid } } } }
      post '/v3/route_policies', body.to_json, headers
      expect(last_response.status).to eq(422)
      get '/v3/route_policies?sources=cf:svc:route-team:missing-worker', nil, admin_headers_for(user)
      expect(last_response.status).to eq(200)
      expect(parsed_response['resources']).to eq([])
    end

    it 'resolves a qualified source to an immutable account reference and removes grants on deletion' do
      TestConfig.override(service_account_router_contract_version: 2)
      org = create(:organization, service_account_prefix: 'route-team')
      space = create(:space, organization: org)
      account = ServiceAccountModel.create(name: 'route-worker', space: space)
      domain = create(:private_domain, owning_organization: org, enforce_route_policies: true, route_policies_scope: 'space')
      route = create(:route, space: space, domain: domain)
      headers = admin_headers_for(create(:user))
      body = { source: 'cf:svc:route-team:route-worker', relationships: { route: { data: { guid: route.guid } } } }

      post '/v3/route_policies', body.to_json, headers

      expect(last_response.status).to eq(201)
      expect(parsed_response['source']).to eq(body[:source])
      policy = RoutePolicy.first(guid: parsed_response['guid'])
      expect(policy.source_guid).to eq(account.guid)
      get "/v3/route_policies/#{policy.guid}?include=source", nil, headers
      expect(parsed_response.dig('relationships', 'service_account', 'data', 'guid')).to eq(account.guid)
      expect(parsed_response.dig('included', 'service_accounts').pluck('guid')).to eq([account.guid])
      account.destroy
      expect(RoutePolicy.first(guid: policy.guid)).to be_nil
    end
  end
end
