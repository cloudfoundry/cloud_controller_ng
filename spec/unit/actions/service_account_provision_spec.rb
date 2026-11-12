require 'spec_helper'
require 'actions/service_account_provision' if File.exist?('app/actions/service_account_provision.rb')

module VCAP::CloudController
  RSpec.describe 'Service account provisioning' do
    let(:account) { ServiceAccountModel.create(name: 'payments-worker', space: create(:space, :with_service_account_prefix)) }
    let(:clients) { instance_double(CF::UAA::Scim) }
    let(:action) { VCAP::CloudController.const_get(:ServiceAccountProvision).new(clients, identity_ca_ref: 'diego-instance-identity') }
    let(:registration) do
      {
        'client_id' => account.client_id,
        'authorized_grant_types' => ['client_credentials'],
        'authorities' => %w[cloud_controller.read cloud_controller.write],
        'scope' => [],
        'access_token_validity' => 300,
        'tls-client-auth-ca-ref' => 'diego-instance-identity',
        'tls_client_auth_san_dns' => account.certificate_dns_san,
        'tls_client_certificate_bound_access_tokens' => false,
        'tls-client-auth-required-claims' => { 'org_guid' => account.organization.guid },
        'tls-client-auth-claim-mappings' => [
          { 'field' => 'subject_cn', 'claim' => 'cf_instance_guid' },
          { 'field' => 'subject_ou', 'pattern' => '^app:(.+)$', 'claim' => 'app_guid' },
          { 'field' => 'subject_ou', 'pattern' => '^space:(.+)$', 'claim' => 'space_guid' },
          { 'field' => 'subject_ou', 'pattern' => '^organization:(.+)$', 'claim' => 'org_guid' }
        ],
        'cf_service_account_guid' => account.guid
      }
    end

    it 'creates one canonical client without creating a CAPI user before marking ready' do
      allow(clients).to receive(:get).with(:client, account.client_id).and_raise(CF::UAA::NotFound)
      expect(clients).to receive(:add).with(:client, registration)
      action.provision(account)

      expect(User.first(guid: account.client_id)).to be_nil
      expect(account.reload.status).to eq('ready')
    end

    it 'reuses a matching managed registration after a partial failure or retry' do
      allow(clients).to receive(:get).with(:client, account.client_id).and_return(registration)
      expect(clients).not_to receive(:add)
      action.provision(account)
      action.provision(account)
      expect(User.where(guid: account.client_id).count).to eq(0)
    end

    it 'accepts UAA normalized inert scope during disable reconciliation' do
      account.update(enabled: false)
      allow(clients).to receive(:get).and_return(registration.merge('scope' => ['uaa.none']))
      expect(clients).to receive(:delete).with(:client, account.client_id)
      action.deprovision(account)
      expect(account.reload.status).to eq('disabled')
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

    it 'leaves independently managed CAPI users and their roles untouched during provisioning' do
      principal = create(:user, guid: account.client_id, is_oauth_client: true)
      space = create(:space)
      space.organization.add_user(principal)
      space.add_developer(principal)
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)

      action.provision(account)

      expect(principal.reload.spaces).to include(space)
      expect(account.reload.status).to eq('ready')
    end

    it 'does not delete an existing OAuth principal when deleting a never-provisioned account' do
      principal = create(:user, guid: account.client_id, is_oauth_client: true)
      space = create(:space)
      space.organization.add_user(principal)
      space.add_developer(principal)
      account.update(enabled: false)
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)

      action.deprovision(account, delete: true)

      expect(ServiceAccountModel.first(guid: account.guid)).to be_nil
      expect(principal.reload.spaces).to include(space)
    end

    it 'does not create or modify a CAPI principal when re-enabling a previously provisioned account' do
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)
      action.provision(account)
      principal = create(:user, guid: account.client_id, is_oauth_client: true, active: true)
      space = create(:space)
      space.organization.add_user(principal)
      space.add_developer(principal)
      account.update(enabled: false)
      action.deprovision(account)
      expect(principal.reload.active).to be(true)
      expect(principal.spaces).to include(space)
      principal.destroy
      account.update(enabled: true)

      action.provision(account)

      expect(User.first(guid: account.client_id)).to be_nil
      expect(account.reload.status).to eq('ready')
    end

    it 'retains the independently managed CAPI user and its roles on account deletion' do
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)
      action.provision(account)
      principal = create(:user, guid: account.client_id, is_oauth_client: true)
      space = create(:space)
      space.organization.add_user(principal)
      space.add_developer(principal)
      account.update(enabled: false)

      action.deprovision(account, delete: true)

      expect(User.first(guid: principal.guid).id).to eq(principal.id)
      expect(principal.reload.spaces).to include(space)
    end

    it 'preserves explicit roles through failed re-enable and retry' do
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      allow(clients).to receive(:add)
      action.provision(account)
      principal = create(:user, guid: account.client_id, is_oauth_client: true)
      space = create(:space)
      space.organization.add_user(principal)
      space.add_developer(principal)
      account.update(enabled: false)
      action.deprovision(account)
      account.update(enabled: true)
      allow(clients).to receive(:add).and_raise('UAA unavailable')

      expect { action.provision(account) }.to raise_error('UAA unavailable')
      expect(principal.reload.spaces).to include(space)
      allow(clients).to receive(:add)
      action.provision(account)

      expect(User.first(guid: account.client_id).id).to eq(principal.id)
      expect(principal.reload.spaces).to include(space)
      expect(account.reload.status).to eq('ready')
    end

    it 'does not provision disabled accounts' do
      account.update(enabled: false)
      expect(clients).not_to receive(:get)
      expect { action.provision(account) }.to raise_error(/disabled/)
      expect(account.reload.status).to eq('reserved')
    end

    it 'never registers inline CA certificates' do
      allow(clients).to receive(:get).and_raise(CF::UAA::NotFound)
      expect(clients).to receive(:add) do |_, payload|
        expect(payload).not_to have_key('tls-client-auth-ca')
        expect(payload['tls-client-auth-ca-ref']).to eq('diego-instance-identity')
      end
      action.provision(account)
    end

    [
      { 'tls-client-auth-ca-ref' => 'previous-bundle' },
      { 'tls-client-auth-ca-ref' => nil, 'tls-client-auth-ca' => 'inline-ca' }
    ].each do |altered_trust|
      it "refuses its own marked client with a different trust anchor (#{altered_trust.compact.keys.first})" do
        allow(clients).to receive(:get).and_return(registration.merge(altered_trust).compact)
        expect(clients).not_to receive(:add)
        expect { action.provision(account) }.to raise_error(/client identity collision/)
        expect(account.reload.status).to eq('failed')
      end
    end

    it 'only supports UAA trust bundle references' do
      expect { ServiceAccountProvision.new(clients, identity_ca: 'inline-ca') }.to raise_error(ArgumentError)
    end

    [nil, '', ' '].each do |reference|
      it "requires a nonblank trust bundle reference (#{reference.inspect})" do
        expect { ServiceAccountProvision.new(clients, identity_ca_ref: reference) }.
          to raise_error(ArgumentError, /identity_ca_ref must name a UAA trust bundle/)
      end
    end

    context 'with the real UAA client library' do
      let(:uaa_url) { 'https://service-account-uaa.example.test' }
      let(:clients) { CF::UAA::Scim.new(uaa_url, 'bearer test-token') }
      let(:client_url) { "#{uaa_url}/oauth/clients/#{account.client_id}" }
      let(:response_headers) { { 'content-type' => 'application/json' } }

      it 'serializes the canonical secretless registration over HTTP' do
        WebMock::API.stub_request(:get, client_url).to_return(status: 404)
        creation = WebMock::API.stub_request(:post, "#{uaa_url}/oauth/clients").
                   with(headers: { 'Authorization' => 'bearer test-token' }) { |request| Oj.load(request.body) == registration }.
                   to_return(status: 201, headers: response_headers, body: registration.to_json)

        action.provision(account)

        expect(creation).to have_been_requested.once
        expect(account.reload.status).to eq('ready')
      end

      it 'reuses a client with omitted empty scopes and reordered authorities on repeated reconciliation' do
        response = registration.except('scope').merge('authorities' => registration['authorities'].reverse)
        WebMock::API.stub_request(:get, client_url).
          to_return(headers: response_headers, body: response.to_json)

        action.provision(account)
        action.provision(account)

        expect(account.reload.status).to eq('ready')
        expect(User.where(guid: account.client_id).count).to eq(0)
        expect(WebMock::API.a_request(:post, "#{uaa_url}/oauth/clients")).not_to have_been_made
      end

      [
        { 'scope' => ['clients.admin'] },
        { 'authorities' => %w[cloud_controller.read cloud_controller.write cloud_controller.admin] },
        { 'tls-client-auth-sub-template' => 'admin' },
        { 'tls-client-auth-aud-templates' => ['other-api'] },
        { 'tls_client_auth_subject_dn' => 'CN=other' }
      ].each do |altered_policy|
        it "refuses an existing client with altered #{altered_policy.keys.first}" do
          WebMock::API.stub_request(:get, client_url).
            to_return(headers: response_headers, body: registration.merge(altered_policy).to_json)

          expect { action.provision(account) }.to raise_error(ServiceAccountProvision::Conflict, 'client identity collision')

          expect(account.reload.status).to eq('failed')
          expect(User.first(guid: account.client_id)).to be_nil
          expect(WebMock::API.a_request(:post, "#{uaa_url}/oauth/clients")).not_to have_been_made
        end
      end
    end
  end
end
