require 'spec_helper'
require 'presenters/v3/service_binding_model_presenter'

module VCAP::CloudController
  describe ServiceBindingModelPresenter do
    describe '#present_json' do
      it 'returns the right things' do
        credentials = { 'very-secret' => 'password' }.to_json
        service_binding = ServiceBindingModel.make(created_at: Time.at(1), updated_at: Time.at(2), credentials: credentials, syslog_drain_url: 'syslog:/syslog.com')

        json_result = ServiceBindingModelPresenter.new.present_json(service_binding)
        result = MultiJson.load(json_result)

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
