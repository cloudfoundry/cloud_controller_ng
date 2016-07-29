require 'spec_helper'
require 'presenters/v3/service_binding_model_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ServiceBindingModelPresenter do
    let(:presenter) { ServiceBindingModelPresenter.new(service_binding) }
    let(:credentials) { { 'very-secret' => 'password' }.to_json }
    let(:volume_mounts) { [{ 'container_dir' => '/a/reasonable/path', 'device' => { 'very-secret' => 'password' } }] }
    let(:censored_volume_mounts) { [{ 'container_dir' => '/a/reasonable/path' }] }
    let(:service_binding) { VCAP::CloudController::ServiceBindingModel.make(
      created_at: Time.at(1),
      updated_at: Time.at(2),
      credentials: credentials,
      syslog_drain_url: 'syslog:/syslog.com',
      volume_mounts: volume_mounts)
    }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the model as a hash' do
        expect(result[:guid]).to eq(service_binding.guid)
        expect(result[:type]).to eq(service_binding.type)
        expect(result[:data].to_hash[:credentials]).to eq(credentials)
        expect(result[:data].to_hash[:syslog_drain_url]).to eq(service_binding.syslog_drain_url)
        expect(result[:data].to_hash[:volume_mounts]).to eq(censored_volume_mounts)
        expect(result[:created_at]).to eq('1970-01-01T00:00:01Z')
        expect(result[:updated_at]).to eq('1970-01-01T00:00:02Z')
        expect(result[:links]).to include(:self)
        expect(result[:links]).to include(:service_instance)
        expect(result[:links]).to include(:app)
      end

      context 'when show_secrets is false' do
        let(:result) { ServiceBindingModelPresenter.new(service_binding, show_secrets: false).to_hash }

        it 'redacts credentials' do
          expect(result[:data][:credentials]).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end
      end
    end
  end
end
