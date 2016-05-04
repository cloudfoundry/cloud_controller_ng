require 'spec_helper'
require 'presenters/v3/service_binding_model_presenter'

module VCAP::CloudController
  describe ServiceBindingModelPresenter do
    let(:presenter) { ServiceBindingModelPresenter.new(service_binding) }
    let(:credentials) { { 'very-secret' => 'password' }.to_json }
    let(:service_binding) { ServiceBindingModel.make(created_at: Time.at(1), updated_at: Time.at(2), credentials: credentials, syslog_drain_url: 'syslog:/syslog.com') }

    describe '#to_hash' do
      it 'matches #to_json' do
        hash = presenter.to_hash
        json = MultiJson.load(presenter.to_json)
        expect(hash.deep_stringify_keys).to eq(json)
        expect(hash).to eq(json.deep_symbolize_keys)
      end
    end

    describe '#to_json' do
      let(:result) { MultiJson.load(presenter.to_json) }

      it 'returns the right things' do
        expect(result['guid']).to eq(service_binding.guid)
        expect(result['type']).to eq(service_binding.type)
        expect(result['data']['credentials']).to eq(credentials)
        expect(result['data']['syslog_drain_url']).to eq(service_binding.syslog_drain_url)
        expect(result['created_at']).to eq('1970-01-01T00:00:01Z')
        expect(result['updated_at']).to eq('1970-01-01T00:00:02Z')
        expect(result['links']).to include('self')
        expect(result['links']).to include('service_instance')
        expect(result['links']).to include('app')
      end
    end
  end
end
