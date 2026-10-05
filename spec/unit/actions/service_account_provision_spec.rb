require 'spec_helper'
require 'actions/service_account_provision' if File.exist?('app/actions/service_account_provision.rb')

module VCAP::CloudController
  RSpec.describe 'Service account provisioning' do
    let(:account) { ServiceAccountModel.create(name: 'payments-worker', space: create(:space)) }
    let(:clients) { instance_double(CF::UAA::Scim) }
    let(:action) { VCAP::CloudController.const_get(:ServiceAccountProvision).new(clients, identity_ca: 'trusted-ca') }
    let(:registration) do
      {
        'client_id' => account.client_id,
        'authorized_grant_types' => ['client_credentials'],
        'authorities' => %w[cloud_controller.read cloud_controller.write],
        'scope' => [],
        'access_token_validity' => 300,
        'tls-client-auth-ca' => 'trusted-ca',
        'tls_client_auth_san_dns' => account.certificate_dns_san,
        'cf_service_account_guid' => account.guid
      }
    end

    it 'creates one canonical client and a roleless OAuth principal before marking ready' do
      allow(clients).to receive(:get).with(:client, account.client_id).and_raise(CF::UAA::NotFound)
      expect(clients).to receive(:add).with(:client, registration)
      action.provision(account)

      principal = User.first(guid: account.client_id)
      expect(principal.is_oauth_client).to be(true)
      expect(principal.organizations).to be_empty
      expect(principal.spaces).to be_empty
      expect(account.reload.status).to eq('ready')
    end

    it 'reuses a matching managed registration after a partial failure or retry' do
      allow(clients).to receive(:get).with(:client, account.client_id).and_return(registration)
      expect(clients).not_to receive(:add)
      action.provision(account)
      action.provision(account)
      expect(User.where(guid: account.client_id).count).to eq(1)
    end

    it 'does not adopt an existing unmanaged client even if its SAN matches' do
      allow(clients).to receive(:get).and_return(registration.except('cf_service_account_guid'))
      expect(clients).not_to receive(:add)
      expect { action.provision(account) }.to raise_error(/client identity collision/)
      expect(account.reload.status).to eq('failed')
      expect(User.first(guid: account.client_id)).to be_nil
    end

    it 'refuses a managed registration with altered trust policy' do
      allow(clients).to receive(:get).and_return(registration.merge('tls_client_auth_san_dns' => 'other.svc.identity'))
      expect { action.provision(account) }.to raise_error(/client identity collision/)
      expect(account.reload.status).to eq('failed')
    end

    it 'leaves a visible failed state on UAA failure and can retry' do
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add).and_raise(StandardError, 'unavailable')
      expect { action.provision(account) }.to raise_error('unavailable')
      expect(account.reload.status).to eq('failed')
      expect(User.first(guid: account.client_id)).to be_nil
      allow(clients).to receive(:add).and_return(registration)
      action.provision(account)
      expect(account.reload.status).to eq('ready')
    end

    it 'refuses to repurpose an existing human principal' do
      create(:user, guid: account.client_id, is_oauth_client: false)
      expect(clients).not_to receive(:get)
      expect { action.provision(account) }.to raise_error(/principal identity collision/)
      expect(account.reload.status).to eq('failed')
    end

    it 'does not provision disabled accounts' do
      account.update(enabled: false)
      expect(clients).not_to receive(:get)
      expect { action.provision(account) }.to raise_error(/disabled/)
      expect(account.reload.status).to eq('reserved')
    end
  end
end
