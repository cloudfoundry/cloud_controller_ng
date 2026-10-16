require 'spec_helper'
require 'cloud_controller/dependency_locator'

module VCAP::CloudController
  RSpec.describe 'Configured service account provisioner', job_context: :worker do
    let(:locator) { CloudController::DependencyLocator.instance }
    let(:settings) { { client_id: 'account-manager', client_secret: 'manager-secret', identity_ca: 'instance-identity-ca' } }
    let(:account) { ServiceAccountModel.create(name: 'payments-worker', space: create(:space)) }
    let(:uaa_url) { 'https://uaa.service.cf.internal' }
    let(:headers) { { 'content-type' => 'application/json' } }
    let(:worker_config) { Config.read_file('config/cloud_controller.yml').merge(service_account_provisioning: settings) }

    before do
      UaaTokenCache.clear!
      TestConfig.override(service_account_provisioning: settings)
    end

    it 'accepts complete worker configuration' do
      expect { ConfigSchemas::WorkerSchema.validate(worker_config) }.not_to raise_error
    end

    it 'validates provisioning configuration for API-hosted local workers too' do
      api_config = Config.read_file('config/cloud_controller.yml').merge(service_account_provisioning: settings.except(:client_id))
      expect { ConfigSchemas::ApiSchema.validate(api_config) }.to raise_error(Membrane::SchemaValidationError, /client_id => Missing key/)
    end

    %i[client_id client_secret].each do |key|
      it "rejects worker configuration missing #{key}" do
        worker_config[:service_account_provisioning] = settings.except(key)
        expect { ConfigSchemas::WorkerSchema.validate(worker_config) }.to raise_error(Membrane::SchemaValidationError, /#{key} => Missing key/)
      end
    end

    %i[client_id client_secret identity_ca].each do |key|
      it "fails closed before authentication with blank #{key}" do
        TestConfig.override(service_account_provisioning: settings.merge(key => ' '))
        expect { locator.service_account_provisioner }.to raise_error(/service account provisioning is not configured/)
      end
    end

    context 'with a UAA trust bundle reference instead of inline CA certificates' do
      let(:settings) { { client_id: 'account-manager', client_secret: 'manager-secret', identity_ca_ref: 'diego-instance-identity' } }

      it 'accepts the reference in worker and API configuration' do
        expect { ConfigSchemas::WorkerSchema.validate(worker_config) }.not_to raise_error
        api_config = Config.read_file('config/cloud_controller.yml').merge(service_account_provisioning: settings)
        expect { ConfigSchemas::ApiSchema.validate(api_config) }.not_to raise_error
      end

      it 'registers account clients with the configured reference' do
        WebMock::API.stub_request(:post, "#{uaa_url}/oauth/token").
          to_return(headers: headers, body: { access_token: 'manager-token', token_type: 'bearer', expires_in: 300 }.to_json)
        WebMock::API.stub_request(:get, "#{uaa_url}/oauth/clients/#{account.client_id}").to_return(status: 404)
        creation = WebMock::API.stub_request(:post, "#{uaa_url}/oauth/clients").with do |request|
          payload = Oj.load(request.body)
          payload['tls-client-auth-ca-ref'] == 'diego-instance-identity' && !payload.key?('tls-client-auth-ca')
        end.to_return(status: 201, headers: headers, body: { client_id: account.client_id }.to_json)

        locator.service_account_provisioner.provision(account)

        expect(creation).to have_been_requested.once
      end

      it 'updates an owned inline-CA client to the reference through the configured management client' do
        WebMock::API.stub_request(:post, "#{uaa_url}/oauth/token").
          to_return(headers: headers, body: { access_token: 'manager-token', token_type: 'bearer', expires_in: 300 }.to_json)
        existing = {
          client_id: account.client_id, authorized_grant_types: ['client_credentials'],
          authorities: %w[cloud_controller.read cloud_controller.write], access_token_validity: 300,
          'tls-client-auth-ca' => 'instance-identity-ca', tls_client_auth_san_dns: account.certificate_dns_san,
          cf_service_account_guid: account.guid
        }
        WebMock::API.stub_request(:get, "#{uaa_url}/oauth/clients/#{account.client_id}").
          to_return(headers: headers, body: existing.to_json)
        update = WebMock::API.stub_request(:put, "#{uaa_url}/oauth/clients/#{account.client_id}").
                 with(headers: { 'Authorization' => 'bearer manager-token' }) do |request|
                   payload = Oj.load(request.body)
                   payload['tls-client-auth-ca-ref'] == 'diego-instance-identity' &&
                     payload.key?('tls-client-auth-ca') && payload['tls-client-auth-ca'].nil?
                 end.to_return(headers: headers, body: existing.to_json)

        locator.service_account_provisioner.provision(account)

        expect(update).to have_been_requested.once
        expect(account.reload.status).to eq('ready')
      end
    end

    it 'fails closed when both inline CA certificates and a bundle reference are configured' do
      TestConfig.override(service_account_provisioning: settings.merge(identity_ca_ref: 'diego-instance-identity'))
      expect { locator.service_account_provisioner }.to raise_error(/service account provisioning is not configured/)
    end

    it 'fails closed when neither inline CA certificates nor a bundle reference are configured' do
      TestConfig.override(service_account_provisioning: settings.except(:identity_ca))
      expect { locator.service_account_provisioner }.to raise_error(/service account provisioning is not configured/)
    end

    it 'uses only the configured management credentials and instance identity CA' do
      token = WebMock::API.stub_request(:post, "#{uaa_url}/oauth/token").
              with(basic_auth: %w[account-manager manager-secret], body: { 'grant_type' => 'client_credentials' }).
              to_return(headers: headers, body: { access_token: 'manager-token', token_type: 'bearer', expires_in: 300 }.to_json)
      WebMock::API.stub_request(:get, "#{uaa_url}/oauth/clients/#{account.client_id}").
        with(headers: { 'Authorization' => 'bearer manager-token' }).to_return(status: 404)
      creation = WebMock::API.stub_request(:post, "#{uaa_url}/oauth/clients").
                 with(headers: { 'Authorization' => 'bearer manager-token' }) do |request|
                   payload = Oj.load(request.body)
                   payload['client_id'] == account.client_id &&
                     payload['tls-client-auth-ca'] == settings[:identity_ca] &&
                     payload['tls_client_auth_san_dns'] == account.certificate_dns_san &&
                     !payload.key?('client_secret')
                 end.to_return(status: 201, headers: headers, body: { client_id: account.client_id }.to_json)

      provisioner = locator.service_account_provisioner
      expect(locator.service_account_provisioner).to equal(provisioner)
      provisioner.provision(account)

      expect(account.reload.status).to eq('ready')
      expect(token).to have_been_requested.at_least_once
      expect(creation).to have_been_requested.once
    end

    it 'refreshes an invalid cached management token before retrying client creation' do
      UaaTokenCache.set_token(settings[:client_id], 'bearer expired-token')
      WebMock::API.stub_request(:get, "#{uaa_url}/oauth/clients/#{account.client_id}").to_return(status: 404)
      WebMock::API.stub_request(:post, "#{uaa_url}/oauth/clients").
        with(headers: { 'Authorization' => 'bearer expired-token' }).
        to_return(status: 401, headers: headers, body: { error: 'invalid_token' }.to_json)
      WebMock::API.stub_request(:post, "#{uaa_url}/oauth/token").
        to_return(headers: headers, body: { access_token: 'refreshed-token', token_type: 'bearer', expires_in: 300 }.to_json)
      creation = WebMock::API.stub_request(:post, "#{uaa_url}/oauth/clients").
                 with(headers: { 'Authorization' => 'bearer refreshed-token' }).
                 to_return(status: 201, headers: headers, body: { client_id: account.client_id }.to_json)

      locator.service_account_provisioner.provision(account)

      expect(account.reload.status).to eq('ready')
      expect(creation).to have_been_requested.once
    end

    it 'fails closed without configuration and does not fall back to another UAA client' do
      TestConfig.override(service_account_provisioning: nil)
      expect { locator.service_account_provisioner }.to raise_error(/service account provisioning is not configured/)
    end
  end
end
