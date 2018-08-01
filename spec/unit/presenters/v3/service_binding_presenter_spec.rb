require 'spec_helper'
require 'presenters/v3/service_binding_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ServiceBindingPresenter do
    let(:presenter) { described_class.new(service_binding) }
    let(:credentials) { { 'very-secret' => 'password' }.to_json }
    let(:volume_mounts) { [{ 'container_dir' => '/a/reasonable/path', 'device' => { 'very-secret' => 'password' } }] }
    let(:censored_volume_mounts) { [{ 'container_dir' => '/a/reasonable/path' }] }
    let(:service_binding) { VCAP::CloudController::ServiceBinding.make(
      created_at: Time.at(1),
      credentials: credentials,
      syslog_drain_url: 'syslog:/syslog.com',
      volume_mounts: volume_mounts)
    }
    let(:scheme) { TestConfig.config[:external_protocol] }
    let(:host) { TestConfig.config[:external_domain] }
    let(:link_prefix) { "#{scheme}://#{host}" }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the model as a hash' do
        links = {
          self: { href: "#{link_prefix}/v3/service_bindings/#{service_binding.guid}" },
          service_instance: { href: "#{link_prefix}/v2/service_instances/#{service_binding.service_instance.guid}" },
          app: { href: "#{link_prefix}/v3/apps/#{service_binding.app_guid}" }
        }

        expect(result[:guid]).to eq(service_binding.guid)
        expect(result[:type]).to eq(service_binding.type)
        expect(result[:data].to_hash[:credentials]).to eq(credentials)
        expect(result[:data].to_hash[:syslog_drain_url]).to eq(service_binding.syslog_drain_url)
        expect(result[:data].to_hash[:volume_mounts]).to eq(censored_volume_mounts)
        expect(result[:created_at]).to eq('1970-01-01T00:00:01Z')
        expect(result[:updated_at]).to eq(service_binding.updated_at)
        expect(result[:links]).to include(:self)
        expect(result[:links]).to include(:service_instance)
        expect(result[:links]).to include(:app)
        expect(result[:links]).to eq(links)
      end

      context 'when show_secrets is false' do
        let(:result) { described_class.new(service_binding, show_secrets: false).to_hash }

        it 'redacts credentials' do
          expect(result[:data][:credentials]).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end
      end
    end
  end
end
