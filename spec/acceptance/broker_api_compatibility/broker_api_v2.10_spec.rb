require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.10' do
    include VCAP::CloudController::BrokerApiHelper

    let(:catalog) { default_catalog(plan_updateable: true) }

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    describe 'Binding' do
      let(:broker_response_status) { 200 }
      let(:broker_response_body) do
        {
            'volume_mounts' => [{
                 'device_type' => 'shared',
                 'other' => 'stuff',
                 'device' => { 'volume_id' => 'foo', 'mount_config' => { 'extra' => 'garbage' } },
                 'mode' => 'rw',
                 'container_dir' => '/var/vcap/data/foo',
                 'driver' => 'mydriver'
             }]
        }.to_json
      end
      let(:app_guid) { @app_guid }
      let(:service_instance_guid) { @service_instance_guid }
      let(:catalog) { default_catalog(requires: ['volume_mount']) }

      before do
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
               admin_headers)

          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['entity']['volume_mounts']).to match_array([{ 'device_type' => 'shared', 'mode' => 'rw', 'container_dir' => '/var/vcap/data/foo' }])
        end
      end
    end
  end
end
