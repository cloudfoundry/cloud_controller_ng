require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.13' do
    include VCAP::CloudController::BrokerApiHelper

    let(:create_instance_schema) { { 'type': 'object' } }
    let(:update_instance_schema) { {} }
    let(:schemas) {
      {
        'service_instance' => {
          'create' => {
            'parameters' => create_instance_schema
          },
          'update' => {}
        }
      }
    }

    let(:catalog) { default_catalog(plan_schemas: schemas) }

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    context 'when a broker catalog defines a create plan schema' do
      let(:create_instance_schema) {
        {
          '$schema' => 'http://json-schema.org/draft-04/schema#',
          'type' => 'object'
        }
      }

      it 'responds with the schema for a service plan entry' do
        get("/v2/service_plans/#{@plan_guid}",
            {}.to_json,
            json_headers(admin_headers))

        parsed_body = MultiJson.load(last_response.body)
        expect(parsed_body['entity']['schemas']).to eq({ 'service_instance' => {
            'create' => { 'parameters' => {'$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object'} },
            'update' => { 'parameters' => {} }
        } })
      end
    end

    context 'when the broker catalog defines a plan without schemas' do
      it 'responds with an empty schema' do
        get("/v2/service_plans/#{@large_plan_guid}",
            {}.to_json,
            json_headers(admin_headers))

        parsed_body = MultiJson.load(last_response.body)
        expect(parsed_body['entity']['schemas']).to eq({ 'service_instance' => { 'create' => { 'parameters' => {} }, 'update' => { 'parameters' => {} } } })
      end
    end

    context 'when the broker catalog has an invalid schema' do
      before do
        update_broker(default_catalog(plan_schemas: { 'service_instance' => { 'create' => true } }))
      end

      it 'returns an error' do
        parsed_body = MultiJson.load(last_response.body)

        expect(parsed_body['code']).to eq(270012)
        expect(parsed_body['description']).to include('Schemas service_instance.create must be a hash, but has value true')
      end
    end
  end
end
