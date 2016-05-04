require 'spec_helper'

describe 'Service Broker API integration' do
  describe 'v2.9' do
    include VCAP::CloudController::BrokerApiHelper

    before { setup_cc }

    describe 'Binding' do
      let(:broker_response_status) { 200 }
      let(:broker_response_body) do
        {
          volume_mounts: [
            {
              public_property: 'public value',
              private: {
                private_property: 'private value'
              }
            }
          ]
        }.to_json
      end
      let(:app_guid) { @app_guid }
      let(:service_instance_guid) { @service_instance_guid }
      let(:request_from_cc_to_broker) do
        {
          plan_id: 'plan1-guid-here',
          service_id: 'service-guid-here'
        }
      end
      let(:catalog) { default_catalog(requires: ['volume_mount']) }

      before do
        setup_broker(catalog)
        provision_service
        create_app
      end

      after do
        delete_broker
      end

      describe 'service binding response with volume_mounts' do
        before do
          stub_request(:put, %r{/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}}).
            to_return(status: broker_response_status, body: broker_response_body)
        end

        it 'displays the volume mount information to the user' do
          post('/v2/service_bindings',
            { app_guid: app_guid, service_instance_guid: service_instance_guid }.to_json,
            json_headers(admin_headers))

          parsed_body = MultiJson.load(last_response.body)

          expect(VCAP::CloudController::ServiceBinding.last.volume_mounts).to match_array(
            [
              {
                'public_property' => 'public value',
                'private' => { 'private_property' => 'private value' }
              }
            ])
          expect(parsed_body['entity']['volume_mounts']).to match_array([{ 'public_property' => 'public value' }])
        end
      end
    end
  end
end
