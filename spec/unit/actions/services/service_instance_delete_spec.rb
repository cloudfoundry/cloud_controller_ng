require 'spec_helper'
require 'actions/services/service_instance_delete'

module VCAP::CloudController
  RSpec.describe ServiceInstanceDelete do
    let(:event_repository) { Repositories::ServiceEventRepository.new(user: user, user_email: user_email) }

    subject(:service_instance_delete) { ServiceInstanceDelete.new(event_repository: event_repository) }

    describe '#delete' do
      let!(:service_instance_1) { ManagedServiceInstance.make(:routing) }
      let!(:service_instance_2) { ManagedServiceInstance.make(:routing) }

      let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance_1) }
      let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance_2) }

      let!(:route_1) { Route.make(space: service_instance_1.space) }
      let!(:route_2) { Route.make(space: service_instance_2.space) }
      let!(:route_binding_1) { RouteBinding.make(route: route_1, service_instance: service_instance_1) }
      let!(:route_binding_2) { RouteBinding.make(route: route_2, service_instance: service_instance_2) }

      let!(:service_instance_dataset) { ServiceInstance.dataset }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      before do
        [service_instance_1, service_instance_2].each do |service_instance|
          stub_deprovision(service_instance)
          stub_unbind(service_instance.service_bindings.first)
        end

        stub_unbind(route_binding_1)
        stub_unbind(route_binding_2)
      end

      it 'deletes all the service_instances' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceInstance.count }.by(-2)
      end

      it 'deletes all the bindings for all the service instance' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceBinding.count }.by(-2)
      end

      it 'deletes all the route bindings for all the service instance' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { RouteBinding.count }.by(-2)
      end

      it 'deletes user provided service instances' do
        user_provided_instance = UserProvidedServiceInstance.make
        errors = service_instance_delete.delete(service_instance_dataset)
        expect(errors).to be_empty

        expect(user_provided_instance.exists?).to be_falsey
      end

      it 'deletes the last operation for each managed service instance' do
        instance_operation_1 = ServiceInstanceOperation.make(state: 'succeeded')
        service_instance_1.service_instance_operation = instance_operation_1
        service_instance_1.save

        errors = service_instance_delete.delete(service_instance_dataset)
        expect(errors).to be_empty

        expect(service_instance_1.exists?).to be_falsey
        expect(instance_operation_1.exists?).to be_falsey
      end

      it 'defaults accepts_incomplete to false' do
        service_instance_delete.delete([service_instance_1])
        broker_url = deprovision_url(service_instance_1)
        expect(a_request(:delete, broker_url)).to have_been_made
      end

      context 'when accepts_incomplete is true' do
        let(:service_instance) { ManagedServiceInstance.make }
        let(:multipart_delete) { false }

        subject(:service_instance_delete) do
          ServiceInstanceDelete.new(
            accepts_incomplete: true,
            event_repository: event_repository,
            multipart_delete: multipart_delete,
          )
        end

        before do
          stub_deprovision(service_instance, accepts_incomplete: true, status: 202, body: {}.to_json)
        end

        it 'passes the accepts_incomplete flag to the client call' do
          service_instance_delete.delete([service_instance])
          broker_url = deprovision_url(service_instance, accepts_incomplete: true)
          expect(a_request(:delete, broker_url)).to have_been_made
        end

        it 'updates the instance to be in progress' do
          service_instance_delete.delete([service_instance])
          expect(service_instance.last_operation.state).to eq 'in progress'
        end

        it 'enqueues a job to fetch state' do
          service_instance_delete.delete([service_instance])

          job = Delayed::Job.last
          expect(job).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch

          inner_job = job.payload_object.handler.job.job
          expect(inner_job.name).to eq 'service-instance-state-fetch'
          expect(inner_job.client_attrs).to eq service_instance.client.attrs
          expect(inner_job.service_instance_guid).to eq service_instance.guid
          expect(inner_job.request_attrs).to eq({})
          expect(inner_job.poll_interval).to eq(60)
        end

        it 'sets the fetch job to run immediately' do
          Timecop.freeze do
            service_instance_delete.delete([service_instance])

            expect(Delayed::Job.count).to eq 1
            job = Delayed::Job.last

            poll_interval = VCAP::CloudController::Config.config[:broker_client_default_async_poll_interval_seconds].seconds
            expect(job.run_at).to be < Time.now.utc + poll_interval
          end
        end

        context 'and the caller wants to treat accepts_incomplete deprovisioning as a failure during a multipart deletion' do
          let(:multipart_delete) { true }

          it 'should return an error if there is an operation in progress' do
            result = service_instance_delete.delete([service_instance])

            expect(result.length).to be(1)
            expect(result.first.message).to include("An operation for service instance #{service_instance.name} is in progress.")
          end
        end
      end

      context 'when unbinding a service instance times out' do
        before do
          stub_unbind(service_binding_1, body: lambda { |r|
            sleep 10
            raise 'Should time out'
          })
        end

        it 'should leave the service instance unchanged' do
          original_attrs = service_binding_1.as_json
          expect {
            Timeout.timeout(0.5.second) do
              service_instance_delete.delete(service_instance_dataset)
            end
          }.to raise_error(Timeout::Error)

          service_binding_1.reload

          expect(a_request(:delete, unbind_url(service_binding_1))).
            to have_been_made.times(1)
          expect(service_binding_1.as_json).to eq(original_attrs)

          expect(ServiceInstance.first(id: service_instance_1.id)).to be
        end
      end

      context 'when deprovisioning a service instance times out' do
        before do
          stub_deprovision(service_instance_1, body: lambda { |r|
            sleep 10
            raise 'Should time out'
          })
        end

        it 'should mark the service instance as failed' do
          expect {
            Timeout.timeout(0.5.second) do
              service_instance_delete.delete(service_instance_dataset)
            end
          }.to raise_error(Timeout::Error)

          service_instance_1.reload

          expect(a_request(:delete, deprovision_url(service_instance_1))).
            to have_been_made.times(1)
          expect(service_instance_1.last_operation.type).to eq('delete')
          expect(service_instance_1.last_operation.state).to eq('failed')
        end
      end

      context 'when a service instance has an operation in progress' do
        before do
          service_instance_1.service_instance_operation = ServiceInstanceOperation.make(state: 'in progress')
        end

        it 'returns an operation in progress error for route and service bindings' do
          errors = service_instance_delete.delete(service_instance_dataset)
          expect(errors.length).to eq 2
          expect(errors.first.name).to eq 'AsyncServiceInstanceOperationInProgress'
          expect(errors.second.name).to eq 'AsyncServiceInstanceOperationInProgress'
        end

        it 'keeps the instance in an `in progress` state' do
          service_instance_delete.delete(service_instance_dataset)
          expect(service_instance_1.last_operation.reload.state).to eq 'in progress'
        end
      end

      context 'when the broker returns an error for one of the deletions' do
        let(:error_status_code) { 500 }

        before do
          stub_deprovision(service_instance_2, status: error_status_code)
        end

        it 'does not rollback previous deletions of service instances' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete(service_instance_dataset)
          expect(ServiceInstance.count).to eq 1
        end

        it 'returns errors it has captured' do
          errors = service_instance_delete.delete(service_instance_dataset)
          expect(errors.count).to eq(1)
          expect(errors[0]).to be_instance_of(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)
        end

        it 'fails the last operation of the service instance' do
          service_instance_delete.delete(service_instance_dataset)
          expect(service_instance_2.last_operation.state).to eq('failed')
        end
      end

      context 'when the broker returns an error for route unbinding' do
        before do
          stub_unbind(route_binding_2, status: 500)
        end

        it 'does not rollback previous deletions of service instances' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete(service_instance_dataset)
          expect(ServiceInstance.count).to eq 1
        end

        it 'propagates service unbind errors' do
          errors = service_instance_delete.delete(service_instance_dataset)
          expect(errors.count).to eq(1)
          expect(errors[0]).to be_instance_of(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)
        end

        it 'does not attempt to delete that service instance' do
          service_instance_delete.delete(service_instance_dataset)
          expect(service_instance_1.exists?).to be_falsey
          expect(service_instance_2.exists?).to be_truthy

          broker_url_1 = deprovision_url(service_instance_1, accepts_incomplete: nil)
          broker_url_2 = deprovision_url(service_instance_2, accepts_incomplete: nil)
          expect(a_request(:delete, broker_url_1)).to have_been_made
          expect(a_request(:delete, broker_url_2)).not_to have_been_made
        end
      end

      context 'when the broker returns an error for unbinding' do
        before do
          stub_unbind(service_instance_2.service_bindings.first, status: 500)
        end

        it 'does not rollback previous deletions of service instances' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete(service_instance_dataset)
          expect(ServiceInstance.count).to eq 1
        end

        it 'propagates service unbind errors' do
          errors = service_instance_delete.delete(service_instance_dataset)
          expect(errors.count).to eq(1)
          expect(errors[0]).to be_instance_of(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)
        end

        it 'does not attempt to delete that service instance' do
          service_instance_delete.delete(service_instance_dataset)
          expect(service_instance_1.exists?).to be_falsey
          expect(service_instance_2.exists?).to be_truthy

          broker_url_1 = deprovision_url(service_instance_1, accepts_incomplete: nil)
          broker_url_2 = deprovision_url(service_instance_2, accepts_incomplete: nil)
          expect(a_request(:delete, broker_url_1)).to have_been_made
          expect(a_request(:delete, broker_url_2)).not_to have_been_made
        end
      end

      context 'when deletion from the database fails for a service instance' do
        before do
          allow(service_instance_2).to receive(:destroy).and_raise('BOOM')
        end

        it 'does not rollback previous deletions of service instances' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete([service_instance_1, service_instance_2])
          expect(ServiceInstance.count).to eq 1
        end

        it 'returns errors it has captured' do
          errors = service_instance_delete.delete([service_instance_1, service_instance_2])
          expect(errors.count).to eq(1)
          expect(errors[0].message).to eq 'BOOM'
        end
      end

      context 'when deleting already deleted service instance' do
        it 'does not throw errors as element is missing anyway' do
          expect(ServiceInstance.count).to eq 2
          service_instance_delete.delete([service_instance_1])
          errors = service_instance_delete.delete([service_instance_1])
          expect(ServiceInstance.count).to eq 1

          expect(errors.count).to eq(0)
        end
      end
    end
  end
end
