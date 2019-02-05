require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.15' do
    include VCAP::CloudController::BrokerApiHelper

    before { setup_cc }

    describe 'updates service instances based on the plan object of the catalog' do
      context 'when the broker supports plan_updateable on plan level' do
        let(:catalog) do
          catalog = default_catalog
          catalog[:services].first[:plans].first[:plan_updateable] = true
          catalog
        end

        before do
          setup_broker(catalog)
        end

        it 'successfully updates the service instance plan' do
          provision_service
          expect(VCAP::CloudController::ServiceInstance.find(guid: @service_instance_guid).service_plan_guid).to eq @plan_guid

          update_service_instance(200)
          expect(last_response).to have_status_code(201)
          expect(VCAP::CloudController::ServiceInstance.find(guid: @service_instance_guid).service_plan_guid).to eq @large_plan_guid
        end
      end
    end

    describe 'platform delays polling to last_operation based on Retry-After header' do
      let(:default_poll_interval) { VCAP::CloudController::Config.config.get(:broker_client_default_async_poll_interval_seconds) }
      let(:retry_after_interval) { default_poll_interval * 4 }

      before do
        setup_broker(default_catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        stub_async_last_operation(body: { state: 'in progress' }, headers: { 'Retry-After': retry_after_interval })
      end

      context 'when provisioning a service instance' do
        it 'should schedule a delayed job with correct run_at time' do
          async_provision_service

          expect(
            a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          assert_cc_uses_specified_polling_interval(
            service_instance,
            default_poll_interval,
            retry_after_interval
          )
        end
      end

      context 'when deprovisioning a service instance' do
        let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

        before do
          @service_instance_guid = service_instance.guid
        end

        it 'should schedule a delayed job with correct run_at time' do
          async_delete_service

          expect(
            a_request(:delete, deprovision_url(service_instance, accepts_incomplete: true))
          ).to have_been_made

          assert_cc_uses_specified_polling_interval(
            service_instance,
            default_poll_interval,
            retry_after_interval
          )
        end
      end
    end
  end
end

def assert_cc_uses_specified_polling_interval(service_instance, default_poll_interval, retry_after_interval)
  Timecop.freeze(Time.now) do
    Delayed::Worker.new.work_off
    expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made

    Timecop.travel(default_poll_interval.seconds)
    Delayed::Worker.new.work_off
    expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made.once

    Timecop.travel(retry_after_interval.seconds)
    Delayed::Worker.new.work_off
    expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made.twice
  end
end
