require 'db_spec_helper'
require 'actions/v3/service_instance_delete'
require 'cloud_controller/user_audit_info'

module VCAP::CloudController
  module V3
    RSpec.describe ServiceInstanceDelete do
      subject(:action) { described_class.new(service_instance, event_repository) }
      let(:user_guid) { Sham.uaa_id }
      let(:user_audit_info) { instance_double(UserAuditInfo, { user_guid: user_guid }) }
      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository)
        allow(dbl).to receive(:record_user_provided_service_instance_event)
        allow(dbl).to receive(:record_service_instance_event)
        allow(dbl).to receive(:user_audit_info).and_return(user_audit_info)
        dbl
      end

      describe '#blocking_operation_in_progress?' do
        describe 'managed service instance' do
          let!(:service_instance) do
            VCAP::CloudController::ManagedServiceInstance.make.tap do |si|
              si.save_with_new_operation({}, { type: last_operation_type, state: last_operation_state })
            end
          end

          describe 'delete in progress' do
            let(:last_operation_type) { 'delete' }
            let(:last_operation_state) { 'in progress' }

            it 'is blocking' do
              expect(action.blocking_operation_in_progress?).to be_truthy
            end
          end

          describe 'create in progress' do
            let(:last_operation_type) { 'create' }
            let(:last_operation_state) { 'in progress' }

            it 'is not blocking' do
              expect(action.blocking_operation_in_progress?).to be_falsey
            end
          end

          describe 'operation not in progress' do
            let(:last_operation_type) { 'delete' }
            let(:last_operation_state) { 'failed' }

            it 'is not blocking' do
              expect(action.blocking_operation_in_progress?).to be_falsey
            end
          end
        end

        describe 'user provided service instances' do
          let!(:service_instance) do
            VCAP::CloudController::UserProvidedServiceInstance.make.tap do |si|
              si.save_with_new_operation({}, { type: 'create', state: 'succeeded' })
            end
          end

          it 'is not blocking' do
            expect(action.blocking_operation_in_progress?).to be_falsey
          end
        end
      end

      describe '#delete' do
        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        context 'user-provided service instances' do
          let!(:service_instance) do
            si = VCAP::CloudController::UserProvidedServiceInstance.make(
              name: 'foo',
              credentials: {
                foo: 'bar',
                baz: 'qux'
              },
              syslog_drain_url: 'https://foo.com',
              route_service_url: 'https://bar.com',
              tags: %w(accounting mongodb)
            )
            si.label_ids = [
              VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
              VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
            ]
            si.annotation_ids = [
              VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
              VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
            ]
            si.service_instance_operation = VCAP::CloudController::ServiceInstanceOperation.make(type: 'update', state: 'succeeded')
            si
          end
          let(:deprovision_response) do
            {
              last_operation: {
                state: 'succeeded',
              }
            }
          end
          let(:client) do
            instance_double(VCAP::Services::ServiceBrokers::UserProvided::Client, {
              deprovision: deprovision_response,
            })
          end

          it 'sends a deprovision to the client' do
            action.delete

            expect(VCAP::Services::ServiceClientProvider).to have_received(:provide).with(instance: service_instance)
            expect(client).to have_received(:deprovision).with(
              service_instance,
              accepts_incomplete: true,
              user_guid: user_guid
            )
          end

          it 'deletes it from the database' do
            subject.delete

            expect(ServiceInstance.all).to be_empty
          end

          it 'creates an audit event' do
            subject.delete

            expect(event_repository).to have_received(:record_user_provided_service_instance_event).with(
              :delete,
              instance_of(UserProvidedServiceInstance)
            )
          end

          it 'returns finished' do
            result = action.delete
            expect(result[:finished]).to be_truthy
          end

          context 'when there are bindings' do
            let(:delete_route_binding_action) do
              double(ServiceRouteBindingDelete).tap do |d|
                allow(d).to receive(:delete) do |binding|
                  binding.destroy
                  { finished: true }
                end
              end
            end
            let(:delete_service_binding_action) do
              double(ServiceCredentialBindingDelete).tap do |d|
                allow(d).to receive(:delete) do |binding|
                  binding.destroy
                  { finished: true }
                end
              end
            end

            let!(:route_binding_1) { RouteBinding.make(service_instance: service_instance) }
            let!(:route_binding_2) { RouteBinding.make(service_instance: service_instance) }
            let!(:route_binding_3) { RouteBinding.make(service_instance: service_instance) }
            let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance) }
            let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance) }
            let!(:service_binding_3) { ServiceBinding.make(service_instance: service_instance) }

            before do
              allow(ServiceRouteBindingDelete).to receive(:new).and_return(delete_route_binding_action)
              allow(ServiceCredentialBindingDelete).to receive(:new).and_return(delete_service_binding_action)
            end

            it 'unbinds all the bindings and unshares the spaces' do
              action.delete

              expect(ServiceRouteBindingDelete).to have_received(:new).with(event_repository.user_audit_info)
              expect(delete_route_binding_action).to have_received(:delete).with(route_binding_1)
              expect(delete_route_binding_action).to have_received(:delete).with(route_binding_2)
              expect(delete_route_binding_action).to have_received(:delete).with(route_binding_3)

              expect(ServiceCredentialBindingDelete).to have_received(:new).with(:credential, event_repository.user_audit_info)
              expect(delete_service_binding_action).to have_received(:delete).with(service_binding_1)
              expect(delete_service_binding_action).to have_received(:delete).with(service_binding_2)
              expect(delete_service_binding_action).to have_received(:delete).with(service_binding_3)
            end

            context 'when deleting bindings raises' do
              let(:delete_route_binding_action) do
                double(ServiceRouteBindingDelete).tap do |d|
                  allow(d).to receive(:delete) do |binding|
                    raise StandardError.new('boom-route') if binding == route_binding_2

                    binding.destroy
                    { finished: true }
                  end
                end
              end

              let(:delete_service_binding_action) do
                double(ServiceCredentialBindingDelete).tap do |d|
                  allow(d).to receive(:delete) do |binding|
                    raise StandardError.new('boom-credential') if binding == service_binding_2

                    binding.destroy
                    { finished: true }
                  end
                end
              end

              it 'attempts to remove the other bindings' do
                expect {
                  action.delete
                }.to raise_error(StandardError, 'boom-route')

                expect(ServiceInstance.all).to contain_exactly(service_instance)
                expect(RouteBinding.all).to contain_exactly(route_binding_2)
                expect(ServiceBinding.all).to contain_exactly(service_binding_2)
              end
            end
          end
        end

        context 'managed service instances' do
          let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }

          let(:deprovision_response) do
            {
              last_operation: {
                type: 'delete',
                state: 'succeeded',
              }
            }
          end
          let(:client) do
            instance_double(VCAP::Services::ServiceBrokers::V2::Client, {
              deprovision: deprovision_response,
            })
          end

          it 'sends a deprovision to the client' do
            action.delete

            expect(VCAP::Services::ServiceClientProvider).to have_received(:provide).with(instance: service_instance)
            expect(client).to have_received(:deprovision).with(
              service_instance,
              accepts_incomplete: true,
              user_guid: user_guid
            )
          end

          context 'when the client succeeds synchronously' do
            it 'deletes it from the database' do
              subject.delete

              expect(ServiceInstance.all).to be_empty
            end

            it 'creates an audit event' do
              subject.delete

              expect(event_repository).to have_received(:record_service_instance_event).with(
                :delete,
                instance_of(ManagedServiceInstance)
              )
            end

            it 'returns finished' do
              result = action.delete
              expect(result[:finished]).to be_truthy
            end
          end

          context 'when the client responds asynchronously' do
            let(:operation) { Sham.guid }
            let(:deprovision_response) do
              {
                last_operation: {
                  type: 'delete',
                  state: 'in progress',
                  broker_provided_operation: operation,
                }
              }
            end

            it 'updates the last operation' do
              action.delete

              expect(ServiceInstance.first.last_operation.type).to eq('delete')
              expect(ServiceInstance.first.last_operation.state).to eq('in progress')
              expect(ServiceInstance.first.last_operation.broker_provided_operation).to eq(operation)
            end

            it 'creates an audit event' do
              action.delete

              expect(event_repository).to have_received(:record_service_instance_event).with(
                :start_delete,
                instance_of(ManagedServiceInstance)
              )
            end

            it 'returns incomplete' do
              result = action.delete
              expect(result[:finished]).to be_falsey
              expect(result[:operation]).to eq(operation)
            end
          end

          context 'when an update operation is already in progress' do
            before do
              service_instance.save_with_new_operation({}, { type: 'update', state: 'in progress' })
            end

            it 'should raise' do
              expect {
                action.delete
              }.to raise_error(CloudController::Errors::ApiError, "An operation for service instance #{service_instance.name} is in progress.")
            end
          end

          context 'when a create operation is already in progress' do
            let(:create_operation) { Sham.guid }
            before do
              service_instance.save_with_new_operation({}, { type: 'create', state: 'in progress', broker_provided_operation: create_operation })
            end

            context 'broker accepts delete request' do
              it 'should delete the service instance' do
                action.delete

                expect(ServiceInstance.all).to be_empty
              end
            end

            context 'broker rejects delete request' do
              before do
                allow(client).to receive(:deprovision).and_raise(
                  CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name))
              end

              it 'should leave create in progress' do
                expect {
                  action.delete
                }.to raise_error(CloudController::Errors::ApiError, "An operation for service instance #{service_instance.name} is in progress.")

                expect(ServiceInstance.first.last_operation.type).to eq('create')
                expect(ServiceInstance.first.last_operation.state).to eq('in progress')
                expect(ServiceInstance.first.last_operation.broker_provided_operation).to eq(create_operation)
              end
            end
          end

          context 'when a delete operation is already in progress' do
            before do
              service_instance.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
            end

            it 'should raise' do
              expect {
                action.delete
              }.to raise_error(CloudController::Errors::ApiError, "An operation for service instance #{service_instance.name} is in progress.")
            end
          end

          context 'when the client raises' do
            before do
              allow(client).to receive(:deprovision).and_raise(StandardError, 'bang')
            end

            it 'saves the failure in last operation' do
              expect {
                action.delete
              }.to raise_error(StandardError, 'bang')

              expect(ServiceInstance.first.last_operation.type).to eq('delete')
              expect(ServiceInstance.first.last_operation.state).to eq('failed')
              expect(ServiceInstance.first.last_operation.description).to eq('bang')
            end
          end

          context 'when there are bindings and shares' do
            context 'sync broker response' do
              let(:delete_service_binding_action) do
                double(ServiceCredentialBindingDelete).tap do |d|
                  allow(d).to receive(:delete) do |binding|
                    binding.destroy
                    { finished: true }
                  end
                end
              end
              let(:delete_service_key_action) do
                double(ServiceCredentialBindingDelete).tap do |d|
                  allow(d).to receive(:delete) do |binding|
                    binding.destroy
                    { finished: true }
                  end
                end
              end
              let(:unshare_action) do
                double(ServiceInstanceUnshare).tap do |d|
                  allow(d).to receive(:unshare) { |si, s, _| si.remove_shared_space(s) }
                end
              end

              let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance) }
              let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance) }
              let!(:service_binding_3) { ServiceBinding.make(service_instance: service_instance) }
              let!(:service_key_1) { ServiceKey.make(service_instance: service_instance) }
              let!(:service_key_2) { ServiceKey.make(service_instance: service_instance) }
              let!(:service_key_3) { ServiceKey.make(service_instance: service_instance) }
              let!(:shared_space_1) { Space.make.tap { |s| service_instance.add_shared_space(s) } }
              let!(:shared_space_2) { Space.make.tap { |s| service_instance.add_shared_space(s) } }
              let!(:shared_space_3) { Space.make.tap { |s| service_instance.add_shared_space(s) } }

              before do
                allow(ServiceCredentialBindingDelete).to receive(:new) { |type, _| type == :credential ? delete_service_binding_action : delete_service_key_action }
                allow(ServiceInstanceUnshare).to receive(:new).and_return(unshare_action)
              end

              it 'unbinds all the bindings and unshares the spaces' do
                action.delete

                expect(ServiceCredentialBindingDelete).to have_received(:new).with(:credential, event_repository.user_audit_info)
                expect(delete_service_binding_action).to have_received(:delete).with(service_binding_1)
                expect(delete_service_binding_action).to have_received(:delete).with(service_binding_2)
                expect(delete_service_binding_action).to have_received(:delete).with(service_binding_3)

                expect(ServiceCredentialBindingDelete).to have_received(:new).with(:key, event_repository.user_audit_info)
                expect(delete_service_key_action).to have_received(:delete).with(service_key_1)
                expect(delete_service_key_action).to have_received(:delete).with(service_key_2)
                expect(delete_service_key_action).to have_received(:delete).with(service_key_3)

                expect(ServiceInstanceUnshare).to have_received(:new)
                expect(unshare_action).to have_received(:unshare).with(service_instance, shared_space_1, event_repository.user_audit_info)
                expect(unshare_action).to have_received(:unshare).with(service_instance, shared_space_2, event_repository.user_audit_info)
                expect(unshare_action).to have_received(:unshare).with(service_instance, shared_space_3, event_repository.user_audit_info)
              end

              context 'when deleting bindings or unsharing spaces raises' do
                let(:delete_service_binding_action) do
                  double(ServiceCredentialBindingDelete).tap do |d|
                    allow(d).to receive(:delete) do |binding|
                      raise StandardError.new('boom-credential') if binding == service_binding_2

                      binding.destroy
                      { finished: true }
                    end
                  end
                end

                let(:delete_service_key_action) do
                  double(ServiceCredentialBindingDelete).tap do |d|
                    allow(d).to receive(:delete) do |binding|
                      raise StandardError.new('boom-key') if binding == service_key_2

                      binding.destroy
                      { finished: true }
                    end
                  end
                end

                let(:unshare_action) do
                  double(ServiceInstanceUnshare).tap do |d|
                    allow(d).to receive(:unshare) do |si, s, _|
                      raise StandardError.new('boom-unshared') if s == shared_space_2

                      si.remove_shared_space(s)
                    end
                  end
                end

                it 'attempts to remove the other bindings and shares' do
                  expect {
                    action.delete
                  }.to raise_error(StandardError, 'boom-credential')

                  expect(ServiceInstance.all).to contain_exactly(service_instance)
                  expect(ServiceBinding.all).to contain_exactly(service_binding_2)
                  expect(ServiceKey.all).to contain_exactly(service_key_2)
                  expect(ServiceInstance.first.shared_spaces).to contain_exactly(shared_space_2)
                end
              end
            end

            context 'async broker response' do
              context 'route binding' do
                let!(:service_offering) { Service.make(requires: %w(route_forwarding)) }
                let!(:service_plan) { ServicePlan.make(service: service_offering) }
                let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
                let!(:route_binding) { RouteBinding.make(service_instance: service_instance) }
                let(:delete_route_binding_action) do
                  double(ServiceRouteBindingDelete).tap do |d|
                    allow(d).to receive(:delete).and_return({ finished: false })
                  end
                end

                before do
                  allow(ServiceRouteBindingDelete).to receive(:new).and_return(delete_route_binding_action)
                end

                it 'fails and schedules a polling job' do
                  expect {
                    action.delete
                  }.to raise_error(
                    ServiceInstanceDelete::UnbindingOperatationInProgress,
                    "An operation for a service binding of service instance #{service_instance.name} is in progress.",
                  )

                  expect(Delayed::Job.all).to have(1).job
                end
              end

              context 'service bindings' do
                let!(:service_binding) { ServiceBinding.make(service_instance: service_instance) }
                let(:delete_service_binding_action) do
                  double(ServiceCredentialBindingDelete).tap do |d|
                    allow(d).to receive(:delete).and_return({ finished: false })
                  end
                end

                before do
                  allow(ServiceCredentialBindingDelete).to receive(:new).and_return(delete_service_binding_action)
                end

                it 'fails and schedules a polling job' do
                  expect {
                    action.delete
                  }.to raise_error(
                    ServiceInstanceDelete::UnbindingOperatationInProgress,
                    "An operation for the service binding between app #{service_binding.app.name} and service instance #{service_instance.name} is in progress.",
                  )

                  expect(Delayed::Job.all).to have(1).job
                end
              end

              context 'service keys' do
                let!(:service_key) { ServiceKey.make(service_instance: service_instance) }
                let(:delete_service_binding_action) do
                  double(ServiceCredentialBindingDelete).tap do |d|
                    allow(d).to receive(:delete).and_return({ finished: false })
                  end
                end

                before do
                  allow(ServiceCredentialBindingDelete).to receive(:new).and_return(delete_service_binding_action)
                end

                it 'fails and schedules a polling job' do
                  expect {
                    action.delete
                  }.to raise_error(
                    ServiceInstanceDelete::UnbindingOperatationInProgress,
                    "An operation for a service binding of service instance #{service_instance.name} is in progress.",
                  )

                  expect(Delayed::Job.all).to have(1).job
                end
              end
            end
          end
        end
      end

      describe '#poll' do
        let!(:service_instance) do
          VCAP::CloudController::ManagedServiceInstance.make.tap do |i|
            i.save_with_new_operation(
              {},
              {
                type: 'delete',
                state: 'in progress',
                broker_provided_operation: operation_id
              }
            )
          end
        end

        let(:operation_id) { Sham.guid }
        let(:poll_response) do
          {
            last_operation: {
              state: 'in progress'
            }
          }
        end
        let(:client) do
          instance_double(VCAP::Services::ServiceBrokers::V2::Client, {
            fetch_service_instance_last_operation: poll_response,
          })
        end

        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        it 'sends a poll to the client' do
          action.poll

          expect(client).to have_received(:fetch_service_instance_last_operation).with(
            service_instance,
            user_guid: user_guid
          )
        end

        context 'when the operation is still in progress' do
          let(:description) { Sham.description }
          let(:retry_after) { 42 }
          let(:poll_response) do
            {
              last_operation: {
                state: 'in progress',
                description: description
              },
              retry_after: retry_after
            }
          end

          it 'updates the last operation description' do
            action.poll

            expect(ServiceInstance.first.last_operation.type).to eq('delete')
            expect(ServiceInstance.first.last_operation.state).to eq('in progress')
            expect(ServiceInstance.first.last_operation.broker_provided_operation).to eq(operation_id)
            expect(ServiceInstance.first.last_operation.description).to eq(description)
          end

          it 'returns the correct data' do
            result = action.poll

            expect(result[:finished]).to be_falsey
            expect(result[:retry_after]).to eq(retry_after)
          end
        end

        context 'when the has finished successfully' do
          let(:description) { Sham.description }
          let(:poll_response) do
            {
              last_operation: {
                state: 'succeeded',
                description: description
              },
            }
          end

          it 'removes the service instance from the database' do
            action.poll

            expect(ServiceInstance.all).to be_empty
          end

          it 'creates an audit event' do
            action.poll

            expect(event_repository).to have_received(:record_service_instance_event).with(
              :delete,
              instance_of(ManagedServiceInstance)
            )
          end

          it 'returns finished' do
            result = action.poll

            expect(result[:finished]).to be_truthy
          end
        end

        context 'when the operation has failed' do
          let(:description) { Sham.description }
          let(:poll_response) do
            {
              last_operation: {
                state: 'failed',
                description: description
              },
            }
          end

          it 'raises and updates the last operation description' do
            expect {
              action.poll
            }.to raise_error(CloudController::Errors::ApiError, "delete could not be completed: #{description}")

            expect(ServiceInstance.first.last_operation.type).to eq('delete')
            expect(ServiceInstance.first.last_operation.state).to eq('failed')
            expect(ServiceInstance.first.last_operation.broker_provided_operation).to be_nil
            expect(ServiceInstance.first.last_operation.description).to eq(description)
          end
        end

        context 'when the client raises' do
          before do
            allow(client).to receive(:fetch_service_instance_last_operation).and_raise(StandardError, 'boom')
          end

          it 'updates the last operation description and continues to poll' do
            result = action.poll
            expect(result[:finished]).to be_falsey

            expect(ServiceInstance.first.last_operation.type).to eq('delete')
            expect(ServiceInstance.first.last_operation.state).to eq('failed')
            expect(ServiceInstance.first.last_operation.broker_provided_operation).to be_nil
            expect(ServiceInstance.first.last_operation.description).to eq('boom')
          end
        end
      end

      describe '#update_last_operation_with_failure' do
        let!(:service_instance) do
          ManagedServiceInstance.make.tap do |i|
            i.save_with_new_operation({}, {
              type: 'delete',
              state: 'in progress',
              description: 'doing ok',
              broker_provided_operation: Sham.guid
            })
          end
        end

        it 'saves the message in last operation' do
          action.update_last_operation_with_failure('bad thing')

          expect(service_instance.last_operation.type).to eq('delete')
          expect(service_instance.last_operation.state).to eq('failed')
          expect(service_instance.last_operation.description).to eq('bad thing')
          expect(service_instance.last_operation.broker_provided_operation).to be_nil
        end
      end
    end
  end
end
