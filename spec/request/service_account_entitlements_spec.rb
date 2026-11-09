require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Service account space entitlements' do
    let(:org) { create(:organization, service_account_prefix: 'test-team') }
    let(:space) { create(:space, organization: org) }
    let(:target) { create(:space, organization: org) }
    let(:user) { create(:user) }
    let(:account) { ServiceAccountModel.create(name: 'shared-worker', space: space, status: 'ready') }
    let(:path) { "/v3/service_accounts/#{account.guid}/relationships/spaces" }

    def auth(role)
      set_user_with_header_as_role(role: role, org: org, space: space, user: user)
    end

    def entitle(destination, headers)
      post path, { data: [{ guid: destination.guid }] }.to_json, headers
    end

    it 'allows a developer of both spaces to entitle and bind a second space' do
      headers = auth('space_developer')
      target.add_developer(user)
      entitle(target, headers)
      expect(last_response.status).to eq(200)
      expect(account.reload.entitled_spaces).to contain_exactly(space, target)
      app = create(:app_model, space: target)
      patch "/v3/apps/#{app.guid}/relationships/service_account", { data: { guid: account.guid } }.to_json, headers
      expect(last_response.status).to eq(200)
      expect(app.reload.service_account_guid).to eq(account.guid)
    end

    it 'requires development access to both an entitled source and destination space' do
      headers = auth('space_developer')
      entitle(target, headers)
      expect(last_response.status).to eq(403)
      expect(account.reload.entitled_spaces).to contain_exactly(space)
    end

    it 'rejects cross-org entitlements even for admins' do
      entitle(create(:space), auth('admin'))
      expect(last_response.status).to eq(422)
      expect(account.reload.entitled_spaces).to contain_exactly(space)
    end

    it 'shows org managers zero-entitlement accounts and filters by organization' do
      headers = auth('org_manager')
      account.remove_all_entitled_spaces
      get "/v3/service_accounts/#{account.guid}", nil, headers
      expect(last_response.status).to eq(200)
      expect(parsed_response.dig('relationships', 'organization', 'data', 'guid')).to eq(org.guid)
      get "/v3/service_accounts?organization_guids=#{org.guid}", nil, headers
      expect(last_response.status).to eq(200)
      expect(parsed_response['resources'].pluck('guid')).to eq([account.guid])
    end

    it 'blocks revocation while desired or active workload references use the account' do
      headers = auth('org_manager')
      entitle(target, headers)
      expect(last_response.status).to eq(200)
      app = create(:app_model, space: target, service_account: account)
      delete "#{path}/#{target.guid}", nil, headers
      expect(last_response.status).to eq(409)
      app.update(service_account: nil)
      process = create(:process_model, app: app, state: ProcessModel::STARTED, service_account_guid: account.guid, service_account_snapshot: true)
      process.update(service_account_guid: account.guid, service_account_snapshot: true)
      delete "#{path}/#{target.guid}", nil, headers
      expect(last_response.status).to eq(409)
      process.destroy
      delete "#{path}/#{target.guid}", nil, headers
      expect(last_response.status).to eq(200)
    end

    it 'does not let a developer revoke the last entitlement but permits org managers' do
      delete "#{path}/#{space.guid}", nil, auth('space_developer')
      expect(last_response.status).to eq(409)
      delete "#{path}/#{space.guid}", nil, auth('org_manager')
      expect(last_response.status).to eq(200)
      expect(account.reload.entitled_spaces).to be_empty
    end

    it 'allows a developer to create an account with an initial entitlement' do
      body = { name: 'new-worker', relationships: { space: { data: { guid: space.guid } } } }
      post '/v3/service_accounts', body.to_json, auth('space_developer')
      expect(last_response.status).to eq(201)
      expect(ServiceAccountModel.first(guid: parsed_response['guid']).entitled_spaces).to contain_exactly(space)
    end

    it 'refuses entitlements for an org with no allocated prefix' do
      legacy_space = create(:space)
      legacy = ServiceAccountModel.create(name: 'legacy-worker', space: legacy_space)
      destination = create(:space, organization: legacy_space.organization)
      post "/v3/service_accounts/#{legacy.guid}/relationships/spaces", { data: [{ guid: destination.guid }] }.to_json, admin_headers_for(user)
      expect(last_response.status).to eq(422)
    end

    it 'does not let a developer in a suspended entitled space manage the account' do
      headers = auth('space_developer')
      account
      space.update(status: Space::SUSPENDED)
      patch "/v3/service_accounts/#{account.guid}", { description: 'blocked' }.to_json, headers
      expect(last_response.status).to eq(403)
    end
  end
end
