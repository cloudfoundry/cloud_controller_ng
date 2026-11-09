require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Service account org namespaces' do
    let(:user) { create(:user) }
    let(:org) { create(:organization, service_account_prefix: 'acme-payments') }
    let(:space) { create(:space, organization: org) }
    let(:body) { { name: 'payments-worker', relationships: { space: { data: { guid: space.guid } } } } }

    def auth(role='space_developer')
      set_user_with_header_as_role(role: role, org: org, space: space, user: user)
    end

    it 'derives a qualified subject and SAN and permits the same name in another org' do
      post '/v3/service_accounts', body.to_json, auth
      expect(last_response.status).to eq(201)
      expect(parsed_response).to include('client_id' => 'cf:service-account:acme-payments:payments-worker',
                                        'certificate_dns_san' => 'payments-worker.acme-payments.svc.identity')
      other = create(:space, organization: create(:organization, service_account_prefix: 'other-team'))
      post '/v3/service_accounts', body.merge(relationships: { space: { data: { guid: other.guid } } }).to_json, admin_headers_for(user)
      expect(last_response.status).to eq(201)
    end

    it 'rejects creation when the org prefix is unset' do
      other = create(:space)
      post '/v3/service_accounts', body.merge(relationships: { space: { data: { guid: other.guid } } }).to_json, admin_headers_for(user)
      expect(last_response.status).to eq(422)
      expect(parsed_response.dig('errors', 0, 'detail')).to include('prefix')
    end

    it 'timestamps deletion and lets an org manager explicitly reuse the name with a new UUID and audit' do
      post '/v3/service_accounts', body.to_json, auth
      expect(last_response.status).to eq(201)
      old_guid = parsed_response['guid']
      ServiceAccountModel.first(guid: old_guid).destroy
      reservation = ServiceAccountModel.db[:service_account_names].first(name: 'payments-worker', organization_id: org.id)
      expect(reservation[:deleted_at]).to be_a(Time)
      post '/v3/service_accounts', body.to_json, auth
      expect(last_response.status).to eq(409)
      post '/v3/service_accounts', body.merge(reuse_name: true).to_json, auth
      expect(last_response.status).to eq(403)
      post '/v3/service_accounts', body.merge(reuse_name: true).to_json, auth('org_manager')
      expect(last_response.status).to eq(201)
      expect(parsed_response['guid']).not_to eq(old_guid)
      expect(parsed_response['status']).to eq('reserved')
      expect(Event.first(type: 'audit.service_account.create', actee: parsed_response['guid']).metadata).to include('reuse_name' => true)
    end
  end
end
