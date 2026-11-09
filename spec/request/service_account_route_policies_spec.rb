require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Service account route sources' do
    it 'resolves a qualified source to an immutable account reference and removes grants on deletion' do
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
      account.destroy
      expect(RoutePolicy.first(guid: policy.guid)).to be_nil
    end
  end
end
