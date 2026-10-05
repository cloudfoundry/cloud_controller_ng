require 'spec_helper'
require 'cloud_controller/diego/service_account_identity' if File.exist?('lib/cloud_controller/diego/service_account_identity.rb')

module VCAP::CloudController::Diego
  RSpec.describe 'Service account runtime identity' do
    let(:app) { create(:app_model) }
    let(:account) { VCAP::CloudController::ServiceAccountModel.create(name: 'payments-worker', space: app.space, status: 'ready') }
    let(:identity) { VCAP::CloudController::Diego.const_get(:ServiceAccountIdentity).new(app, TestConfig.config_instance) }

    before do
      TestConfig.override(service_account_runtime_enabled: true, service_account_token_endpoint: 'https://uaa.example.test/oauth/token/mtls')
      app.update(service_account: account)
    end

    it 'serializes a typed launch identity while preserving organizational units' do
      properties = identity.certificate_properties
      decoded = ::Diego::Bbs::Models::CertificateProperties.decode(properties.to_proto)
      expect(decoded.service_account.name).to eq(account.name)
      expect(decoded.organizational_unit).to eq(["organization:#{app.organization_guid}", "space:#{app.space_guid}", "app:#{app.guid}"])
      app.update(service_account: nil)
      expect(decoded.service_account.name).to eq(account.name)
    end

    it 'exposes non-secret discovery information' do
      metadata = {
        guid: account.guid, name: account.name, client_id: account.client_id, certificate_dns_san: account.certificate_dns_san,
        token_endpoint: 'https://uaa.example.test/oauth/token/mtls'
      }
      expect(identity.environment).to eq('VCAP_SERVICE_ACCOUNT' => metadata)
    end

    %w[reserved reconciling failed disabled deleting].each do |state|
      it "rejects new runtime credentials in #{state} state" do
        account.update(status: state)
        expect { identity.certificate_properties }.to raise_error(CloudController::Errors::ApiError, /not ready/)
      end
    end

    it 'rejects a disabled ready account and a mixed-version disabled runtime' do
      account.update(enabled: false)
      expect { identity.certificate_properties }.to raise_error(CloudController::Errors::ApiError, /not ready/)
      account.update(enabled: true)
      TestConfig.config[:service_account_runtime_enabled] = false
      expect { identity.certificate_properties }.to raise_error(CloudController::Errors::ApiError, /runtime is not enabled/)
    end

    it 'does not give unbound apps account SANs or metadata' do
      app.update(service_account: nil)
      expect(identity.certificate_properties.to_h).not_to have_key(:service_account)
      expect(identity.environment).to eq({})
    end

    it 'rejects token discovery endpoints containing embedded credentials' do
      TestConfig.config[:service_account_token_endpoint] = 'https://user:secret@uaa.example.test/oauth/token/mtls'
      expect { identity.environment }.to raise_error(CloudController::Errors::ApiError, /endpoint/)
    end
  end
end
