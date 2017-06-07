require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.13' do
    include VCAP::CloudController::BrokerApiHelper

    let(:create_instance_schema) { {} }
    let(:schemas) {
      {
        'service_instance' => {
          'create' => {
            'parameters' => create_instance_schema
          }
        }
      }
    }

    let(:catalog) { default_catalog(plan_schemas: schemas) }

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    context 'when a broker catalog defines plan schemas' do
      let(:create_instance_schema) {
        {
          '$schema' => 'http://example.com/schema',
          'type' => 'object'
        }
      }

      it 'is responds with the schema for a service plan entry' do
        get("/v2/service_plans/#{@plan_guid}",
            {}.to_json,
            json_headers(admin_headers))

        parsed_body = MultiJson.load(last_response.body)
        expect(parsed_body['entity']['schemas']).to eq schemas
      end
    end

    context 'when the broker catalog defines a plan without schemas' do
      it 'responds with an empty schema' do
        get("/v2/service_plans/#{@large_plan_guid}",
            {}.to_json,
            json_headers(admin_headers))

        parsed_body = MultiJson.load(last_response.body)
        expect(parsed_body['entity']['schemas']).to eq({ 'service_instance' => { 'create' => { 'parameters' => {} } } })
      end
    end
  end
end
