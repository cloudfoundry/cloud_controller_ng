require 'spec_helper'
require 'actions/service_account_provision'

module VCAP::CloudController
  RSpec.describe 'Service account UAA attribution profile' do
    it 'registers the operator named resource policy without copying audience lists' do
      org = create(:organization, service_account_prefix: 'policy-team')
      account = ServiceAccountModel.create(name: 'policy-worker', space: create(:space, organization: org))
      clients = instance_double(CF::UAA::Scim)
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)
      ServiceAccountProvision.new(clients, identity_ca_ref: 'diego-instance-identity', allowed_resources_ref: 'cf-workload-federation').provision(account)
      expect(clients).to have_received(:add).with(:client, hash_including('tls-client-auth-allowed-resources-ref' => 'cf-workload-federation'))
    end

    it 'registers an explicitly bearer account restricted to its owning org with caller attribution' do
      org = create(:organization, service_account_prefix: 'payments-team')
      account = ServiceAccountModel.create(name: 'payments-worker', space: create(:space, organization: org))
      clients = instance_double(CF::UAA::Scim)
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)

      ServiceAccountProvision.new(clients, identity_ca_ref: 'diego-instance-identity').provision(account)

      profile = {
        'tls_client_certificate_bound_access_tokens' => false,
        'tls-client-auth-required-claims' => { 'org_guid' => org.guid },
        'tls-client-auth-claim-mappings' => [
          { 'field' => 'subject_cn', 'claim' => 'cf_instance_guid' },
          { 'field' => 'subject_ou', 'pattern' => '^app:(.+)$', 'claim' => 'app_guid' },
          { 'field' => 'subject_ou', 'pattern' => '^space:(.+)$', 'claim' => 'space_guid' },
          { 'field' => 'subject_ou', 'pattern' => '^organization:(.+)$', 'claim' => 'org_guid' }
        ]
      }
      expect(clients).to have_received(:add).with(:client, hash_including(profile))
    end
  end
end
