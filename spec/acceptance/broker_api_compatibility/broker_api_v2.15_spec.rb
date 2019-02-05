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

      context 'when provisioning a service instance' do
        before do
          setup_broker(default_catalog)
          @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        end

        it 'should schedule a delayed job with correct run_at time' do
          stub_async_last_operation(body: { state: 'in progress' }, headers: { 'Retry-After': retry_after_interval })
          async_provision_service

          expect(
            a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          Timecop.freeze(Time.now) do
            # Initial call is made immediately after the job is scheduled
            Delayed::Worker.new.work_off
            expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made

            # Check a call on the default interval has not been made, i.e. still have the initial call to last_operation
            Timecop.travel(default_poll_interval.seconds)
            Delayed::Worker.new.work_off
            expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made.once

            # Check a new call has been made at the Retry-After interval
            Timecop.travel(retry_after_interval.seconds)
            Delayed::Worker.new.work_off
            expect(a_request(:get, %r{#{service_instance_url(service_instance)}/last_operation})).to have_been_made.twice
          end
        end
      end
    end
  end
end
