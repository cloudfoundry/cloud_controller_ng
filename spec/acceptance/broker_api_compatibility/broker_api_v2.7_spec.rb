require 'spec_helper'

describe 'Service Broker API integration' do
  describe 'v2.7' do
    include VCAP::CloudController::BrokerApiHelper

    describe 'Perform async operations' do
      let(:catalog) { default_catalog(plan_updateable: true) }

      before do
        setup_cc
        setup_broker(catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
      end

      context 'update' do
        let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

        before do
          @service_instance_guid = service_instance.guid
        end

        it 'performs the async flow if broker initiates an async operation' do
          async_update_service
          stub_async_last_operation

          expect(
            a_request(:patch, update_url_for_broker(@broker, accepts_incomplete: true))).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          Delayed::Worker.new.work_off

          expect((a_request(:get, "#{service_instance_url(service_instance)}/last_operation"))).to have_been_made

          expect(service_instance.reload.last_operation.state).to eq 'succeeded'
          expect(service_instance.reload.last_operation.type).to eq 'update'
        end

        it 'performs the synchronous flow if broker does not return async response code' do
          async_update_service(status: 200)

          expect(
            a_request(:patch, update_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          expect(service_instance.reload.last_operation.state).to eq 'succeeded'
          expect(service_instance.reload.last_operation.type).to eq 'update'
        end

        it 'marks the service instance as failed if the initial request succeeds, but the async provision fails' do
          async_update_service
          stub_async_last_operation(state: 'failed')

          expect(
            a_request(:patch, update_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made

          Delayed::Worker.new.work_off

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          expect((a_request(:get, "#{service_instance_url(service_instance)}/last_operation"))).to have_been_made

          expect(service_instance.reload.last_operation.state).to eq 'failed'
          expect(service_instance.reload.last_operation.type).to eq 'update'
        end
      end

      context 'delete' do
        let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space_guid: @space_guid, service_plan_guid: @plan_guid) }

        before do
          @service_instance_guid = service_instance.guid
        end

        it 'performs the async flow if broker initiates an async operation' do
          async_delete_service
          stub_async_last_operation

          expect(
            a_request(:delete, deprovision_url(service_instance, accepts_incomplete: true))
          ).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          Delayed::Worker.new.work_off
          expect((a_request(:get, "#{service_instance_url(service_instance)}/last_operation"))).to have_been_made

          expect { service_instance.reload }.to raise_error(Sequel::Error)
        end

        it 'performs the synchronous flow if broker does not return async response code' do
          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          async_delete_service(status: 200)

          expect(
            a_request(:delete, deprovision_url(service_instance, accepts_incomplete: true))
          ).to have_been_made

          expect { service_instance.reload }.to raise_error(Sequel::Error)
        end

        it 'marks the service instance as failed if the initial request succeeds, but the async provision fails' do
          async_delete_service
          stub_async_last_operation(state: 'failed')

          expect(
            a_request(:delete, deprovision_url(service_instance, accepts_incomplete: true))
          ).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          Delayed::Worker.new.work_off
          expect((a_request(:get, "#{service_instance_url(service_instance)}/last_operation"))).to have_been_made

          expect(service_instance.reload.last_operation.state).to eq 'failed'
          expect(service_instance.reload.last_operation.type).to eq 'delete'
        end
      end

      context 'provision' do
        it 'performs the async flow if broker initiates an async operation' do
          async_provision_service
          stub_async_last_operation

          expect(
            a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)

          Delayed::Worker.new.work_off

          expect((a_request(:get, "#{service_instance_url(service_instance)}/last_operation"))).to have_been_made

          expect(service_instance.reload.last_operation.state).to eq 'succeeded'
          expect(service_instance.reload.last_operation.type).to eq 'create'
        end

        it 'performs the synchronous flow if broker does not return async response code' do
          async_provision_service(status: 201)
          stub_async_last_operation

          expect(
            a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          expect(service_instance.reload.last_operation.state).to eq 'succeeded'
          expect(service_instance.reload.last_operation.type).to eq 'create'
        end

        it 'marks the service instance as failed if the initial request succeeds, but the async provision fails' do
          async_provision_service
          stub_async_last_operation(state: 'failed')

          expect(
            a_request(:put, provision_url_for_broker(@broker, accepts_incomplete: true))
          ).to have_been_made

          Delayed::Worker.new.work_off

          service_instance = VCAP::CloudController::ManagedServiceInstance.find(guid: @service_instance_guid)
          expect((a_request(:get, "#{service_instance_url(service_instance)}/last_operation"))).to have_been_made

          expect(service_instance.reload.last_operation.state).to eq 'failed'
          expect(service_instance.reload.last_operation.type).to eq 'create'
        end
      end
    end
  end
end
