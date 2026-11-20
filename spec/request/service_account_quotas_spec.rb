require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Service account org quotas' do
    let(:user) { create(:user) }
    let(:org) { create(:organization, service_account_prefix: 'quota-team') }
    let(:space) { create(:space, organization: org) }
    let(:headers) { admin_headers_for(user) }

    it 'persists quota limits, counts disabled accounts, and frees capacity on deletion without freeing names' do
      post '/v3/organization_quotas', { name: 'account-quota', service_accounts: { total_service_accounts: 1 } }.to_json, headers
      expect(last_response.status).to eq(201)
      expect(parsed_response['service_accounts']).to eq('total_service_accounts' => 1)
      quota = QuotaDefinition.first(guid: parsed_response['guid'])
      org.update(quota_definition: quota)
      body = { name: 'first-worker', relationships: { space: { data: { guid: space.guid } } } }
      post '/v3/service_accounts', body.to_json, headers
      expect(last_response.status).to eq(201)
      account = ServiceAccountModel.first(guid: parsed_response['guid'])
      account.update(enabled: false)
      post '/v3/service_accounts', body.merge(name: 'second-worker').to_json, headers
      expect(last_response.status).to eq(422)
      expect(parsed_response.dig('errors', 0, 'detail')).to include('quota')
      account.destroy
      post '/v3/service_accounts', body.merge(name: 'second-worker').to_json, headers
      expect(last_response.status).to eq(201)
      post '/v3/service_accounts', body.to_json, headers
      expect(last_response.status).not_to eq(201)
      patch "/v3/organization_quotas/#{quota.guid}", { service_accounts: { total_service_accounts: nil } }.to_json, headers
      expect(last_response.status).to eq(200)
      expect(parsed_response['service_accounts']).to eq('total_service_accounts' => nil)
    end

    [-1, 'one', 1.5].each do |limit|
      it "rejects invalid limit #{limit.inspect}" do
        post '/v3/organization_quotas', { name: 'invalid-quota', service_accounts: { total_service_accounts: limit } }.to_json, headers
        expect(last_response.status).to eq(422)
        expect(parsed_response.dig('errors', 0, 'detail')).to include('Service accounts')
      end
    end
  end
end
