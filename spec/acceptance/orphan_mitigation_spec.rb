require 'spec_helper'

module VCAP::CloudController
  describe 'orphan mitigation' do
    include VCAP::CloudController::BrokerApiHelper

    let(:guid_pattern) { '[[:alnum:]-]+' }

    before do
      setup_cc
      setup_broker
    end

    after { delete_broker }

    describe 'service provision with timeout' do
      let(:broker_url) { 'broker-url' }
      let(:space_guid) { @space_guid }
      let(:plan_guid) { @plan_guid }

      before do
        stub_request(:put, %r{#{broker_url}/v2/service_instances/#{guid_pattern}}).to_return { |request|
          raise HTTPClient::TimeoutError.new('fake-timeout')
        }

        stub_request(:delete, %r{#{broker_url}/v2/service_instances/#{guid_pattern}}).
          to_return(status: 200, body: '{}')

        post('/v2/service_instances',
        {
          name:              'test-service',
          space_guid:        space_guid,
          service_plan_guid: plan_guid
        }.to_json,
        json_headers(admin_headers))
      end

      it 'makes the request to the broker and deprovisions' do
        expect(a_request(:put, %r{http://username:password@broker-url/v2/service_instances/#{guid_pattern}})).to have_been_made

        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        expect(a_request(:delete, %r{http://username:password@broker-url/v2/service_instances/#{guid_pattern}})).to have_been_made
      end

      it 'responds to user with 504' do
        expect(last_response.status).to eq(504)
      end
    end

    describe 'service binding with timeout' do
      let(:service_instance_guid) { @service_instance_guid }
      let(:app_guid) { @app_guid }

      before do
        provision_service
        create_app

        stub_request(:put, %r{/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}}).to_return { |request|
          raise HTTPClient::TimeoutError.new('fake-timeout')
        }

        stub_request(:delete, %r{/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}}).
          to_return(status: 200, body: '{}')

        post('/v2/service_bindings',
          { app_guid: app_guid, service_instance_guid: service_instance_guid }.to_json,
          json_headers(admin_headers))
      end

      it 'makes the request to the broker and deprovisions' do
        expect(a_request(:put, %r{http://username:password@broker-url/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}})).
          to have_been_made

        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        expect(a_request(:delete, %r{http://username:password@broker-url/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}})).
          to have_been_made
      end

      it 'responds to user with 504' do
        expect(last_response).to have_status_code(504)
      end
    end
  end
end
