require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.9' do
    include VCAP::CloudController::BrokerApiHelper

    let(:catalog) { default_catalog(plan_updateable: true) }

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    describe 'provision' do
      it 'calls the last operation endpoint with state that was returned in provision' do
        operation_data = 'some_operation_data'
        async_provision_service(operation_data: operation_data)
        stub_async_last_operation(operation_data: operation_data)

        expect(a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))).to have_been_made

        service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
        Delayed::Worker.new.work_off

        expect(a_request(
                 :get,
          "#{service_instance_url(service_instance)}/last_operation?operation=#{operation_data}&plan_id=plan1-guid-here&service_id=service-guid-here"
        )).to have_been_made
      end
    end

    describe 'Last Operation for instances that have already been provisioned' do
      let(:broker_response_status) { 200 }
      let(:broker_response_body) { { state: 'succeeded' }.to_json }
      let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }
      let(:operation_data) { nil }

      let(:expected_request) {
        url = "http://#{stubbed_broker_username}:#{stubbed_broker_password}@#{stubbed_broker_host}" \
        "/v2/service_instances/#{service_instance.guid}/last_operation?plan_id=plan1-guid-here&service_id=service-guid-here"
        if !operation_data.nil?
          url += "&operation=#{operation_data}"
        end
        url
      }

      before do
        @service_instance_guid = service_instance.guid
      end

      describe 'an endpoint that polls a service broker last_operation' do
        it 'performs the async flow if broker initiates an async operation' do
          async_update_service
          stub_async_last_operation

          expect(
            a_request(:patch, update_url_for_broker(@broker, accepts_incomplete: true))).to have_been_made

          Delayed::Worker.new.work_off

          expect(a_request(:get, expected_request)).
            to have_been_made.once
        end
      end

      context 'when the broker returns operation data' do
        let(:operation_data) { 'some_operation_data' }

        it 'calls the endpoint with state that was returned in delete' do
          async_delete_service(operation_data: operation_data)
          stub_async_last_operation(operation_data: operation_data)

          expect(a_request(:delete, deprovision_url(service_instance, accepts_incomplete: true))).to have_been_made

          Delayed::Worker.new.work_off

          expect(a_request(:get, expected_request)).to have_been_made.once
        end

        it 'calls the endpoint with state that was returned in update' do
          async_update_service(operation_data: operation_data)
          stub_async_last_operation(operation_data: operation_data)

          expect(a_request(:patch, update_url_for_broker(@broker, accepts_incomplete: true))).to have_been_made

          Delayed::Worker.new.work_off

          expect(a_request(:get, expected_request)).to have_been_made.once
        end
      end
    end
  end
end
