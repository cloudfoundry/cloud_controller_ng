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

    describe 'Last Operation' do
      let(:broker_response_status) { 200 }
      let(:broker_response_body) { { state: 'succeeded' }.to_json }
      let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }
      let(:service_instance_guid) { service_instance.guid }

      let(:expected_request) {
        "http://#{stubbed_broker_username}:#{stubbed_broker_password}@#{stubbed_broker_host}" \
        "/v2/service_instances/#{service_instance_guid}/last_operation?plan_id=plan1-guid-here&service_id=service-guid-here"
      }

      before do
        @service_instance_guid = service_instance_guid
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
    end
  end
end
