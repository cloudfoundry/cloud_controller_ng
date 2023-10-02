require 'spec_helper'
require 'actions/services/service_instance_create'

module VCAP::CloudController
  RSpec.describe ServiceInstanceCreate do
    let(:event_repository) { instance_double(Repositories::ServiceEventRepository, record_service_instance_event: nil, user_audit_info: user_audit_info) }
    let(:user_audit_info) { instance_double(UserAuditInfo) }
    let(:logger) { double(:logger) }

    subject(:create_action) { ServiceInstanceCreate.new(event_repository, logger) }

    describe '#create' do
      let(:space) { Space.make }
      let(:service_plan) { ServicePlan.make }
      let(:request_attrs) do
        {
          'space_guid' => space.guid,
          'service_plan_guid' => service_plan.guid,
          'name' => 'my-instance',
          'dashboard_url' => 'test-dashboardurl.com'
        }
      end
      let(:dashboard_url) { 'com' }
      let(:broker_response_body) { { credentials: {}, dashboard_url: dashboard_url } }
      let(:last_operation) { { type: 'create', description: '', broker_provided_operation: nil, state: 'succeeded' } }
      let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

      before do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        allow(client).to receive(:provision).and_return({ instance: broker_response_body, last_operation: last_operation })
      end

      it 'creates the service instance with the requested params' do
        expect do
          create_action.create(request_attrs, false)
        end.to change(ServiceInstance, :count).from(0).to(1)
        service_instance = ServiceInstance.where(name: 'my-instance').first
        expect(service_instance.credentials).to eq({})
        expect(service_instance.space.guid).to eq(space.guid)
        expect(service_instance.service_plan.guid).to eq(service_plan.guid)
        expect(service_instance.maintenance_info).to be_nil
      end

      it 'creates a new service instance operation' do
        create_action.create(request_attrs, false)
        expect(ManagedServiceInstance.last.last_operation).to eq(ServiceInstanceOperation.last)
      end

      it 'saves service instance attributes returned by the broker' do
        create_action.create(request_attrs, false)
        instance = ManagedServiceInstance.last

        expect(instance[:dashboard_url]).to eq(dashboard_url)
      end

      it 'creates an audit event' do
        create_action.create(request_attrs, false)
        expect(event_repository).to have_received(:record_service_instance_event).with(:create, an_instance_of(ManagedServiceInstance), request_attrs)
      end

      context 'when there are arbitrary params' do
        let(:parameters) { { 'some-param' => 'some-value' } }
        let(:request_attrs) do
          {
            'space_guid' => space.guid,
            'service_plan_guid' => service_plan.guid,
            'name' => 'my-instance',
            'parameters' => parameters
          }
        end

        it 'passes the params to the client' do
          create_action.create(request_attrs, false)
          expect(client).to have_received(:provision).with(anything, hash_including(arbitrary_parameters: parameters))
        end
      end

      context 'with accepts_incomplete' do
        let(:last_operation) { { type: 'create', description: '', broker_provided_operation: nil, state: 'in progress' } }

        it 'enqueues a fetch job' do
          expect do
            create_action.create(request_attrs, true)
          end.to change(Delayed::Job, :count).from(0).to(1)

          expect(Delayed::Job.first).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch
        end

        it 'logs an audit event' do
          create_action.create(request_attrs, true)
          expect(event_repository).to have_received(:record_service_instance_event).with(:start_create, an_instance_of(ManagedServiceInstance), request_attrs)
        end
      end

      context 'when the instance fails to save to the db' do
        let(:mock_service_resource_cleanup) { double(:mock_service_resource_cleanup, attempt_deprovision_instance: nil) }

        before do
          allow(DatabaseErrorServiceResourceCleanup).to receive(:new).and_return(mock_service_resource_cleanup)
          allow_any_instance_of(ManagedServiceInstance).to receive(:save).and_raise
          allow(logger).to receive(:error)
        end

        it 'attempts to deprovision the instance without using the database' do
          expect do
            create_action.create(request_attrs, false)
          end.to raise_error(RuntimeError)
          expect(mock_service_resource_cleanup).to have_received(:attempt_deprovision_instance)
        end

        it 'logs that it was unable to save' do
          begin
            create_action.create(request_attrs, false)
          rescue StandardError
            nil
          end

          expect(logger).to have_received(:error).with(/Failed to save/)
        end
      end

      context 'when the service plan contains maintenance_info' do
        let(:service_plan) { ServicePlan.make(maintenance_info: { 'version' => '2.0' }) }
        let(:request_attrs) do
          {
            'space_guid' => space.guid,
            'service_plan_guid' => service_plan.guid,
            'name' => 'my-instance'
          }
        end

        it 'stores it for the service instance' do
          create_action.create(request_attrs, false)
          service_instance = ManagedServiceInstance.last

          expect(service_instance.maintenance_info).to eq({ 'version' => '2.0' })
        end

        it 'passes the maintenance_info to the client' do
          create_action.create(request_attrs, false)
          expect(client).to have_received(:provision).with(anything, hash_including(maintenance_info: { 'version' => '2.0' }))
        end
      end
    end
  end
end
