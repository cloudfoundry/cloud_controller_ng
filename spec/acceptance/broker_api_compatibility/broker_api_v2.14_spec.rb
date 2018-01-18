require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.14' do
    include VCAP::CloudController::BrokerApiHelper

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    describe 'fetching service binding configuration parameters' do
      context 'when the brokers catalog does not set bindings_retrievable' do
        let(:catalog) { default_catalog }

        it 'defaults to false' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['bindings_retrievable']).to eq false
        end
      end

      context 'when the brokers catalog has bindings_retrievable set to true' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:bindings_retrievable] = true
          catalog
        end

        it 'returns true' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['bindings_retrievable']).to eq true
        end
      end

      context 'when the brokers catalog has bindings_retrievable set to false' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:bindings_retrievable] = false
          catalog
        end

        it 'shows the service as bindings_retrievable false' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['bindings_retrievable']).to eq false
        end
      end
    end

    describe 'fetching service instance configuration parameters' do
      context 'when the brokers catalog does not set instances_retrievable' do
        let(:catalog) { default_catalog }

        it 'defaults to false' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['instances_retrievable']).to eq false
        end
      end

      context 'when the brokers catalog has instances_retrievable set to true' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:instances_retrievable] = true
          catalog
        end

        it 'returns true' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['instances_retrievable']).to eq true
        end
      end

      context 'when the brokers catalog has instances_retrievable set to false' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:instances_retrievable] = false
          catalog
        end

        it 'shows the service as instances_retrievable false' do
          get("/v2/services/#{@service_guid}",
              {}.to_json,
              json_headers(admin_headers))
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['instances_retrievable']).to eq false
        end
      end
    end
  end
end
