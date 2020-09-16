require 'db_spec_helper'
require 'presenters/v3/service_credential_binding_details_presenter'

module VCAP
  module CloudController
    RSpec.describe Presenters::V3::ServiceCredentialBindingDetailsPresenter do
      let(:instance) { ServiceInstance.make(guid: 'instance-guid') }
      let(:app) { AppModel.make(guid: 'app-guid', space: instance.space) }
      let(:credentials) { { password: 'super secret avocado toast' } }
      let(:credential_binding) do
        ServiceBinding.make(
          name: 'some-name',
          app: app,
          service_instance: instance,
          credentials: credentials,
          volume_mounts: %w{super good},
          syslog_drain_url: 'http://banana.example.com/drain'
        )
      end

      let(:key_binding) {
        ServiceKey.make(
          name: 'some-key',
          service_instance: instance,
          credentials: credentials
        )
      }

      it 'returns the app binding details' do
        presenter = described_class.new(binding: credential_binding, credentials: credential_binding.credentials)
        expect(presenter.to_hash.deep_symbolize_keys).to match(
          {
            credentials: {
              password: 'super secret avocado toast'
            },
            syslog_drain_url: 'http://banana.example.com/drain',
            volume_mounts: ['super', 'good']
          }
        )
      end

      it 'returns the key binding detials' do
        presenter = described_class.new(binding: key_binding, credentials: key_binding.credentials)
        expect(presenter.to_hash.deep_symbolize_keys).to match(
          {
            credentials: {
              password: 'super secret avocado toast'
            }
          }
        )
      end

      context 'when syslog drain is not set' do
        let(:credential_binding) { ServiceBinding.make }

        it 'does not include syslog_drain_url in the response' do
          presenter = described_class.new(binding: credential_binding, credentials: credential_binding.credentials)
          expect(presenter.to_hash).to_not have_key(:syslog_drain_url)
        end
      end

      context 'when volume mounts are not set' do
        let(:credential_binding) { ServiceBinding.make }

        it 'does not include volume_mounts in the response' do
          presenter = described_class.new(binding: credential_binding, credentials: credential_binding.credentials)
          expect(presenter.to_hash).to_not have_key(:volume_mounts)
        end
      end

      context 'when credentials are not set' do
        it 'does not include credentials in the response' do
          presenter = described_class.new(binding: credential_binding, credentials: nil)
          expect(presenter.to_hash).to_not have_key(:credentials)
        end
      end

      context 'when some other credentials are passed in' do
        it 'includes those in the response' do
          presenter = described_class.new(binding: credential_binding, credentials: { hello: 'my friend' })
          expect(presenter.to_hash[:credentials]).to eq({ hello: 'my friend' })
        end
      end
    end
  end
end
