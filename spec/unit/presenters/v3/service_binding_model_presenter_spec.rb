require 'spec_helper'
require 'presenters/v3/service_binding_model_presenter'

module VCAP::CloudController
  describe ServiceBindingModelPresenter do
    let(:presenter) { ServiceBindingModelPresenter.new(pagination_presenter) }
    let(:pagination_presenter) { double(:pagination_presenter) }

    describe '#present_json' do
      it 'returns the right things' do
        credentials = { 'very-secret' => 'password' }.to_json
        service_binding = ServiceBindingModel.make(created_at: Time.at(1), updated_at: Time.at(2), credentials: credentials, syslog_drain_url: 'syslog:/syslog.com')

        json_result = presenter.present_json(service_binding)
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

    describe '#present_json_list' do
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:options) { { page: page, per_page: per_page } }
      let(:total_results) { 2 }
      let(:service_binding_1) { ServiceBindingModel.make }
      let(:service_binding_2) { ServiceBindingModel.make }
      let(:service_bindings) { [service_binding_1, service_binding_2] }
      let(:paginated_result) { PaginatedResult.new(service_bindings, total_results, PaginationOptions.new(options)) }

      before do
        allow(pagination_presenter).to receive(:present_pagination_hash) do |_, url|
          "pagination-#{url}"
        end
      end

      it 'presents the service bindings as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result, 'potato')
        result      = MultiJson.load(json_result)

        guids = result['resources'].collect { |service_binding_json| service_binding_json['guid'] }
        expect(guids).to eq([service_binding_1.guid, service_binding_2.guid])
      end

      it 'includes pagination section' do
        json_result = presenter.present_json_list(paginated_result, 'bazooka')
        result      = MultiJson.load(json_result)

        expect(result['pagination']).to eq('pagination-bazooka')
      end
    end
  end
end
