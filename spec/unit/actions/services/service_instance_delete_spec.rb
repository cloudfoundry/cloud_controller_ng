require 'spec_helper'
require 'actions/services/service_instance_delete'

module VCAP::CloudController
  RSpec.describe ServiceInstanceDelete do
    let(:event_repository) { Repositories::ServiceEventRepository.new(UserAuditInfo.new(user_guid: user.guid, user_email: user_email)) }
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }

    subject(:service_instance_delete) { ServiceInstanceDelete.new(event_repository: event_repository) }

    describe '#delete' do
      let!(:route_service_instance) { ManagedServiceInstance.make(:routing) }
      let!(:managed_service_instance) { ManagedServiceInstance.make }
      let!(:user_provided_service_instance) { UserProvidedServiceInstance.make }

      let!(:service_binding_1) { ServiceBinding.make(service_instance: managed_service_instance) }
      let!(:service_binding_2) { ServiceBinding.make(service_instance: managed_service_instance) }
      let!(:service_binding_3) { ServiceBinding.make(service_instance: user_provided_service_instance) }
      let!(:service_binding_4) { ServiceBinding.make(service_instance: user_provided_service_instance) }

      let!(:route_1) { Route.make(space: route_service_instance.space) }
      let!(:route_2) { Route.make(space: route_service_instance.space) }
      let!(:route_binding_1) { RouteBinding.make(route: route_1, service_instance: route_service_instance) }
      let!(:route_binding_2) { RouteBinding.make(route: route_2, service_instance: route_service_instance) }

      let!(:service_key) { ServiceKey.make(service_instance: managed_service_instance) }

      let(:service_instance_dataset) { ServiceInstance.dataset }

      before do
        [route_service_instance, managed_service_instance].each do |service_instance|
          stub_deprovision(service_instance)
        end

        stub_unbind(service_binding_1)
        stub_unbind(service_binding_2)
        stub_unbind(route_binding_1)
        stub_unbind(route_binding_2)
        stub_unbind(service_key)
      end

      it 'deletes all the service_instances and logs events' do
        expect(event_repository).to receive(:record_service_instance_event).with(:delete, instance_of(ManagedServiceInstance), {}).twice
        expect(event_repository).to receive(:record_user_provided_service_instance_event).with(:delete, instance_of(UserProvidedServiceInstance), {}).once
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceInstance.count }.by(-3)
      end

      it 'deletes all the bindings for all the service instance' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceBinding.count }.by(-4)
      end

      it 'deletes all the route bindings for all the service instance' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { RouteBinding.count }.by(-2)
      end

      it 'deletes associated labels' do
        labels = service_instance_dataset.map { |si| ServiceInstanceLabelModel.make(resource_guid: si.guid) }

        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceInstanceLabelModel.count }.by(-labels.length)
        expect(labels.none?(&:exists?)).to be_truthy
      end

      it 'deletes associated annotations' do
        annotations = service_instance_dataset.map { |si| ServiceInstanceAnnotationModel.make(resource_guid: si.guid) }

        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceInstanceAnnotationModel.count }.by(-annotations.length)
        expect(annotations.none?(&:exists?)).to be_truthy
      end

      it 'deletes user provided service instances' do
        user_provided_instance = UserProvidedServiceInstance.make
        errors, warnings = service_instance_delete.delete(service_instance_dataset)
        expect(errors).to be_empty
        expect(warnings).to be_empty

        expect(user_provided_instance.exists?).to be_falsey
      end

      it 'deletes service keys associated with the service instance' do
        expect {
          service_instance_delete.delete(service_instance_dataset)
        }.to change { ServiceKey.count }.by(-1)
      end

      it 'unshares shared managed service instance and records only one unshare event' do
        shared_to_space = Space.make
        managed_service_instance.add_shared_space(shared_to_space)

        expect(managed_service_instance).to receive(:remove_shared_space)
        expect(route_service_instance).not_to receive(:remove_shared_space)
        expect(Repositories::ServiceInstanceShareEventRepository).to receive(:record_unshare_event).once

        service_instance_delete.delete([managed_service_instance, route_service_instance])
      end

      it 'deletes the last operation for each managed service instance' do
        instance_operation_1 = ServiceInstanceOperation.make(state: 'succeeded')
        route_service_instance.service_instance_operation = instance_operation_1
        route_service_instance.save

        errors, warnings = service_instance_delete.delete(service_instance_dataset)
        expect(errors).to be_empty
        expect(warnings).to be_empty

        expect(route_service_instance.exists?).to be_falsey
        expect(instance_operation_1.exists?).to be_falsey
      end

      it 'defaults accepts_incomplete to false' do
        service_instance_delete.delete([route_service_instance])
        broker_url = deprovision_url(route_service_instance)
        expect(a_request(:delete, broker_url)).to have_been_made
      end

      context 'when accepts_incomplete is true' do
        let(:service_instance) { ManagedServiceInstance.make }

        subject(:service_instance_delete) do
          ServiceInstanceDelete.new(
            accepts_incomplete: true,
            event_repository: event_repository,
          )
        end

        before do
          stub_deprovision(service_instance, accepts_incomplete: true, status: 202, body: {}.to_json)
        end

        it 'passes the accepts_incomplete flag to the client deprovision call' do
          service_instance_delete.delete([service_instance])
          broker_url = deprovision_url(service_instance, accepts_incomplete: true)
          expect(a_request(:delete, broker_url)).to have_been_made
        end

        context 'when there is a service binding' do
          let(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

          context 'when the broker responds asynchronously to the unbind call' do
            before do
              stub_unbind(service_binding, accepts_incomplete: true, status: 202, body: {}.to_json)
            end

            it 'passes the accepts_incomplete flag to the client unbind call' do
              service_instance_delete.delete([service_instance])
              broker_url = unbind_url(service_binding, accepts_incomplete: true)
              expect(a_request(:delete, broker_url)).to have_been_made
            end

            it 'returns an error' do
              errors, _ = service_instance_delete.delete([service_instance])
              expect(errors).to have(1).item
              error = errors.first

              app_name = service_binding.app.name
              instance_name = service_instance.name
              expect(error).to be_instance_of(CloudController::Errors::ApiError)
              expect(error.message).to match "^Deletion of service instance #{instance_name} failed because one or more associated resources could not be deleted\.\n\n"
              expect(error.message).to match "\tAn operation for the service binding between app #{app_name} and service instance #{instance_name} is in progress\.$"
            end
          end

          context 'when the broker responds synchronously to the unbind call' do
            before do
              stub_unbind(service_binding, accepts_incomplete: true, status: 200, body: {}.to_json)
            end

            it 'passes the accepts_incomplete flag to the client unbind call' do
              service_instance_delete.delete([service_instance])
              broker_url = unbind_url(service_binding, accepts_incomplete: true)
              expect(a_request(:delete, broker_url)).to have_been_made
            end

            it 'does not return any errors or warnings' do
              errors, warnings = service_instance_delete.delete([service_instance])
              expect(errors).to be_empty
              expect(warnings).to be_empty
            end
          end
        end

        context 'when there are multiple service bindings' do
          let(:service_binding) { ServiceBinding.make(service_instance: service_instance) }
          let(:service_binding2) { ServiceBinding.make(service_instance: service_instance) }

          context 'when the broker responds asynchronously to all unbind calls' do
            before do
              stub_unbind(service_binding, accepts_incomplete: true, status: 202, body: {}.to_json)
              stub_unbind(service_binding2, accepts_incomplete: true, status: 202, body: {}.to_json)
            end

            it 'returns all errors' do
              errors, _ = service_instance_delete.delete([service_instance])
              expect(errors).to have(1).item
              error = errors.first

              msg = error.message
              instance_name = service_instance.name

              expect(error).to be_instance_of(CloudController::Errors::ApiError)
              expect(msg).to match "^Deletion of service instance #{instance_name} failed because one or more associated resources could not be deleted\.\n\n"
              expect(msg).to match "\tAn operation for the service binding between app #{service_binding.app.name} and service instance #{instance_name} is in progress\."
              expect(msg).to match "\tAn operation for the service binding between app #{service_binding2.app.name} and service instance #{instance_name} is in progress\."
            end
          end

          context 'when the broker responds asynchronously to one of the unbind calls' do
            before do
              stub_unbind(service_binding, accepts_incomplete: true, status: 202, body: {}.to_json)
            end

            it 'returns all errors' do
              errors, _ = service_instance_delete.delete([service_instance])
              expect(errors).to have(1).item
              error = errors.first

              app_name = service_binding.app.name
              instance_name = service_instance.name
              expect(error).to be_instance_of(CloudController::Errors::ApiError)
              expect(error.message).to match "^Deletion of service instance #{instance_name} failed because one or more associated resources could not be deleted\.\n\n"
              expect(error.message).to match "\tAn operation for the service binding between app #{app_name} and service instance #{instance_name} is in progress\.$"
            end
          end
        end

        context 'when there is a binding with operation in progress' do
          let(:service_binding_1) { ServiceBinding.make(service_instance: service_instance) }
          let!(:service_binding_operation) { ServiceBindingOperation.make(state: 'in progress', service_binding_id: service_binding_1.id) }
          let(:service_binding_2) { ServiceBinding.make(service_instance: service_instance) }

          before do
            stub_unbind(service_binding_1, accepts_incomplete: true, status: 202, body: {}.to_json)
            stub_unbind(service_binding_2, accepts_incomplete: true, status: 202, body: {}.to_json)
          end

          it 'returns an error that does not contain duplicate messages' do
            errors, _ = service_instance_delete.delete([service_instance])
            expect(errors).to have(1).item
            error = errors.first

            msg = error.message
            instance_name = service_instance.name

            expect(error).to be_instance_of(CloudController::Errors::ApiError)
            expect(msg).to match "^Deletion of service instance #{instance_name} failed because one or more associated resources could not be deleted\.\n\n"
            expect(msg).to match "\tAn operation for the service binding between app #{service_binding_1.app.name} and service instance #{instance_name} is in progress\."
            expect(msg).to match "\tAn operation for the service binding between app #{service_binding_2.app.name} and service instance #{instance_name} is in progress\."

            expect(msg.split("\t")).to have(3).items
          end
        end

        it 'updates the instance to be in progress' do
          service_instance_delete.delete([service_instance])
          expect(service_instance.last_operation.state).to eq 'in progress'
        end

        it 'enqueues a job to fetch state' do
          service_instance_delete.delete([service_instance])

          job = Delayed::Job.last
          expect(job).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch

          inner_job = job.payload_object.handler.handler
          expect(inner_job.name).to eq 'service-instance-state-fetch'
          expect(inner_job.service_instance_guid).to eq service_instance.guid
          expect(inner_job.request_attrs).to eq({})
          expect(inner_job.poll_interval).to eq(60)
        end

        it 'sets the fetch job to run immediately' do
          Timecop.freeze do
            service_instance_delete.delete([service_instance])

            expect(Delayed::Job.count).to eq 1
            job = Delayed::Job.last

            poll_interval = VCAP::CloudController::Config.config.get(:broker_client_default_async_poll_interval_seconds).seconds
            expect(job.run_at).to be < Time.now.utc + poll_interval
          end
        end

        it 'logs audit event start_delete' do
          expect(event_repository).to receive(:record_service_instance_event).with(:start_delete, service_instance, {}).once
          service_instance_delete.delete([service_instance])
        end
      end

      context 'when unbinding a service instance fails' do
        before do
          stub_unbind(service_binding_1, status: 500)
        end

        it 'should leave the service instance unchanged' do
          original_attrs = managed_service_instance.as_json
          service_instance_delete.delete(service_instance_dataset)

          managed_service_instance.reload

          expect(a_request(:delete, unbind_url(service_binding_1))).
            to have_been_made.times(1)

          expect(managed_service_instance.as_json).to eq(original_attrs)
          expect(service_binding_1.exists?).to be_truthy
        end
      end

      context 'when deprovisioning a service instance fails' do
        before do
          stub_deprovision(route_service_instance, status: 500)
        end

        it 'should mark the service instance as failed' do
          service_instance_delete.delete(service_instance_dataset)
          route_service_instance.reload

          expect(a_request(:delete, deprovision_url(route_service_instance))).
            to have_been_made.times(1)
          expect(route_service_instance.last_operation.type).to eq('delete')
          expect(route_service_instance.last_operation.state).to eq('failed')
        end
      end

      context 'when a service instance has an update operation in progress' do
        before do
          route_service_instance.service_instance_operation = ServiceInstanceOperation.make(
            state: 'in progress',
            type: 'update',
          )
        end

        it 'returns an operation in progress error for route and service bindings' do
          errors, warnings = service_instance_delete.delete(service_instance_dataset)
          expect(warnings).to be_empty
          expect(errors.length).to eq 1
          expect(errors.first.name).to eq 'AsyncServiceInstanceOperationInProgress'
        end

        it 'still exists and is in an `in progress` state' do
          service_instance_delete.delete(service_instance_dataset)
          expect(route_service_instance.last_operation.reload.state).to eq 'in progress'
        end
      end

      context 'when a service instance has a create operation in progress' do
        let(:service_instance) { ManagedServiceInstance.make }

        before do
          service_instance.service_instance_operation = ServiceInstanceOperation.make(
            state: 'in progress',
            type: 'create',
          )
        end

        context 'when service instance deprovision happen to be synchronous' do
          before do
            stub_deprovision(service_instance)
          end

          it 'should delete the instance' do
            expect(event_repository).to receive(:record_service_instance_event).
              with(:delete, instance_of(ManagedServiceInstance), {}).once
            expect {
              service_instance_delete.delete([service_instance])
            }.to change { ServiceInstance.count }.by(-1)
          end

          it 'tells broker to deprovision the service' do
            service_instance_delete.delete([service_instance])
            broker_url = deprovision_url(service_instance)
            expect(a_request(:delete, broker_url)).to have_been_made
          end

          it 'should not return any errors' do
            errors, warnings = service_instance_delete.delete([service_instance])
            expect(warnings).to be_empty
            expect(errors.length).to eq 0
          end
        end

        context 'when service instance deprovision happen to be asynchronous' do
          subject(:service_instance_delete) do
            ServiceInstanceDelete.new(
              accepts_incomplete: true,
              event_repository: event_repository,
            )
          end

          before do
            stub_deprovision(service_instance, accepts_incomplete: true, status: 202, body: {}.to_json)
          end

          it 'passes the accepts_incomplete flag to the client deprovision call' do
            service_instance_delete.delete([service_instance])
            broker_url = deprovision_url(service_instance, accepts_incomplete: true)
            expect(a_request(:delete, broker_url)).to have_been_made
          end

          it 'updates the instance to be in progress' do
            service_instance_delete.delete([service_instance])
            expect(service_instance.last_operation.state).to eq 'in progress'
          end

          it 'updates the instance operation type to be delete' do
            service_instance_delete.delete([service_instance])
            expect(service_instance.last_operation.type).to eq 'delete'
          end

          it 'enqueues a job to fetch state' do
            service_instance_delete.delete([service_instance])

            job = Delayed::Job.last
            expect(job).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch

            inner_job = job.payload_object.handler.handler
            expect(inner_job.name).to eq 'service-instance-state-fetch'
            expect(inner_job.service_instance_guid).to eq service_instance.guid
            expect(inner_job.request_attrs).to eq({})
            expect(inner_job.poll_interval).to eq(60)
          end

          it 'should not delete the instance' do
            expect {
              service_instance_delete.delete([service_instance])
            }.to change { ServiceInstance.count }.by(0)
          end

          context 'when there is an error during service instance delete' do
            before do
              stub_deprovision(service_instance, accepts_incomplete: true, status: 422, body: { error: 'ConcurrencyError' }.to_json)
            end

            it 'does not update the operation type' do
              expect(service_instance.last_operation.type).to eq 'create'
              service_instance_delete.delete([service_instance])
              expect(service_instance.last_operation.type).to eq 'create'
            end

            it 'returns errors it has captured' do
              errors, warnings = service_instance_delete.delete([service_instance])
              expect(warnings).to be_empty
              expect(errors.count).to eq(1)
              expect(errors.first.name).to eq 'AsyncServiceInstanceOperationInProgress'
            end
          end
        end
      end

      context 'when the broker returns an error for one of the deletions' do
        let(:error_status_code) { 500 }

        before do
          stub_deprovision(managed_service_instance, status: error_status_code)
        end

        it 'does not rollback previous deletions of service instances' do
          expect {
            service_instance_delete.delete(service_instance_dataset)
          }.to change { ServiceInstance.count }.by(-2)
        end

        it 'returns errors it has captured' do
          errors, warnings = service_instance_delete.delete(service_instance_dataset)
          expect(warnings).to be_empty
          expect(errors.count).to eq(1)
          expect(errors[0]).to be_instance_of(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)
        end

        it 'fails the last operation of the service instance' do
          service_instance_delete.delete(service_instance_dataset)
          expect(managed_service_instance.last_operation.state).to eq('failed')
        end

        it 'only records one delete audit event' do
          expect(event_repository).to receive(:record_service_instance_event).with(:delete, route_service_instance, {}).once
          service_instance_delete.delete(service_instance_dataset)
        end
      end

      context 'when the broker returns an error for route unbinding' do
        before do
          stub_unbind(route_binding_2, status: 500)
        end

        it 'does not rollback previous deletions of service instances' do
          expect {
            service_instance_delete.delete(service_instance_dataset)
          }.to change { ServiceInstance.count }.by(-2)
        end

        it 'propagates service unbind error' do
          errors, warnings = service_instance_delete.delete(service_instance_dataset)
          expect(warnings).to be_empty
          expect(errors).to have(1).item
          error = errors.first
          expect(error).to be_instance_of(CloudController::Errors::ApiError)
          expect(error.message).to match "^Deletion of service instance #{route_service_instance.name} failed because one or more associated resources could not be deleted\.\n\n"
          expect(error.message).to match 'The service broker returned an invalid response'
        end

        it 'does not attempt to delete that service instance' do
          service_instance_delete.delete(service_instance_dataset)
          expect(route_service_instance.exists?).to be_truthy
          expect(managed_service_instance.exists?).to be_falsey

          broker_url_1 = deprovision_url(route_service_instance, accepts_incomplete: nil)
          broker_url_2 = deprovision_url(managed_service_instance, accepts_incomplete: nil)
          expect(a_request(:delete, broker_url_1)).not_to have_been_made
          expect(a_request(:delete, broker_url_2)).to have_been_made
        end
      end

      context 'when the broker returns an error for unbinding' do
        before do
          stub_unbind(managed_service_instance.service_bindings.first, status: 500)
        end

        it 'does not rollback previous deletions of service instances' do
          expect {
            service_instance_delete.delete(service_instance_dataset)
          }.to change { ServiceInstance.count }.by(-2)
        end

        it 'propagates service unbind error' do
          errors, warnings = service_instance_delete.delete(service_instance_dataset)
          expect(warnings).to be_empty
          expect(errors).to have(1).item
          error = errors.first
          expect(error).to be_instance_of(CloudController::Errors::ApiError)
          expect(error.message).to match "^Deletion of service instance #{managed_service_instance.name} failed because one or more associated resources could not be deleted\.\n\n"
          expect(error.message).to match 'The service broker returned an invalid response'
        end

        it 'does not attempt to delete that service instance' do
          service_instance_delete.delete(service_instance_dataset)
          expect(route_service_instance.exists?).to be_falsey
          expect(managed_service_instance.exists?).to be_truthy

          broker_url_1 = deprovision_url(route_service_instance, accepts_incomplete: nil)
          broker_url_2 = deprovision_url(managed_service_instance, accepts_incomplete: nil)
          expect(a_request(:delete, broker_url_1)).to have_been_made
          expect(a_request(:delete, broker_url_2)).not_to have_been_made
        end

        it 'does not attempt to unshare the service instance' do
          shared_to_space = Space.make
          managed_service_instance.add_shared_space(shared_to_space)

          expect_any_instance_of(ServiceInstanceUnshare).not_to receive(:unshare)

          service_instance_delete.delete([managed_service_instance])
        end
      end

      context 'when the broker returns warnings when unbinding' do
        before do
          service_binding_deleter = instance_double(ServiceBindingDelete)
          allow(service_binding_deleter).to receive(:delete) do |service_bindings|
            service_bindings.each(&:destroy)
            [[], ['warning-1', 'warning-2']]
          end

          allow(ServiceBindingDelete).to receive(:new).and_return(service_binding_deleter)
        end

        it 'returns the warnings for all service instances' do
          errors, warnings = service_instance_delete.delete(service_instance_dataset.limit(2))
          expect(errors).to be_empty
          expect(warnings).to match_array(['warning-1', 'warning-2', 'warning-1', 'warning-2'])
        end
      end

      context 'when unsharing fails for a shared service instance' do
        before do
          shared_to_space = Space.make
          managed_service_instance.add_shared_space(shared_to_space)

          allow(managed_service_instance).to receive(:remove_shared_space).and_raise('Unsharing failed')
        end

        it 'does not rollback previous deletions of service instances' do
          expect {
            service_instance_delete.delete([managed_service_instance, route_service_instance])
          }.to change { ServiceInstance.count }.by(-1)
        end

        it 'returns the unbinding error' do
          errors, warnings = service_instance_delete.delete([route_service_instance, managed_service_instance])
          expect(warnings).to be_empty
          expect(errors.count).to eq(1)
          expect(errors[0].message).to match 'Unsharing failed'
        end

        it 'does not record an unshare event' do
          expect(Repositories::ServiceInstanceShareEventRepository).not_to receive(:record_unshare_event)

          service_instance_delete.delete([route_service_instance, managed_service_instance])
        end
      end

      context 'when deletion from the database fails for a service instance' do
        before do
          allow(managed_service_instance).to receive(:destroy).and_raise('BOOM')
        end

        it 'does not rollback previous deletions of service instances' do
          expect {
            service_instance_delete.delete([route_service_instance, managed_service_instance])
          }.to change { ServiceInstance.count }.by(-1)
        end

        it 'returns errors it has captured' do
          errors, warnings = service_instance_delete.delete([route_service_instance, managed_service_instance])
          expect(warnings).to be_empty
          expect(errors.count).to eq(1)
          expect(errors[0].message).to eq 'BOOM'
        end
      end

      context 'when deleting already deleted service instance' do
        it 'does not throw errors as element is missing anyway' do
          expect(ServiceInstance.count).to eq 3
          service_instance_delete.delete([route_service_instance])
          expect(ServiceInstance.count).to eq 2
          errors, warnings = service_instance_delete.delete([route_service_instance])
          expect(warnings).to be_empty

          expect(ServiceInstance.count).to eq 2

          expect(errors.count).to eq(0)
        end
      end
    end

    describe '#can_return_warnings?' do
      it 'returns true' do
        expect(service_instance_delete.can_return_warnings?).to be true
      end
    end
  end
end
