require 'spec_helper'

module VCAP::CloudController
  RSpec.describe UpdaterLock do
    let(:service_instance) { ManagedServiceInstance.make }
    let(:updater_lock) { UpdaterLock.new(service_instance) }
    let(:operation) { ServiceInstanceOperation.make(state: 'override me') }

    before do
      service_instance.service_instance_operation = operation
    end

    describe 'locking' do
      context 'when the instance is unlocked' do
        before do
          updater_lock.lock!
        end

        it 'creates a new service instance operation' do
          expect(service_instance.last_operation.guid).not_to eq(operation.guid)
        end

        it 'sets the last operation of the service instance to "in progress"' do
          expect(service_instance.last_operation.state).to eq('in progress')
        end

        it 'sets the last operation type to "update"' do
          expect(service_instance.last_operation.type).to eq('update')
        end

        it 'does not let you lock again' do
          expect do
            updater_lock.lock!
          end.to raise_error CloudController::Errors::ApiError
        end
      end

      context 'when the instance already has an operation in progress' do
        before do
          service_instance.service_instance_operation = ServiceInstanceOperation.make(state: 'in progress')
        end

        it 'raises an AsyncServiceInstanceOperationInProgress error' do
          expect do
            updater_lock.lock!
          end.to raise_error CloudController::Errors::ApiError do |err|
            expect(err.name).to eq('AsyncServiceInstanceOperationInProgress')
          end
        end
      end

      context 'when the instance has a service binding with an operation in progress' do
        let!(:service_binding_1) { ServiceBinding.make(service_instance:) }
        let!(:service_binding_2) { ServiceBinding.make(service_instance:) }

        before do
          service_binding_2.service_binding_operation = ServiceBindingOperation.make(state: 'in progress')
        end

        it 'raises an ServiceBindingLockedError error' do
          expect do
            updater_lock.lock!
          end.to raise_error LockCheck::ServiceBindingLockedError do |err|
            expect(err.service_binding).to eq(service_binding_2)
          end
        end
      end
    end

    describe 'unlocking' do
      describe 'unlocking and failing' do
        it 'sets the last operation of the service instance to "failed"' do
          updater_lock.unlock_and_fail!
          expect(service_instance.last_operation.state).to eq('failed')
        end

        it 'sets the last operation type to "update"' do
          updater_lock.unlock_and_fail!
          expect(service_instance.last_operation.type).to eq('update')
        end

        it 'does not update the service instance' do
          expect do
            updater_lock.unlock_and_fail!
          end.not_to(change(service_instance, :updated_at))
        end
      end

      describe 'unlocking synchronously' do
        let(:new_service_plan) { ServicePlan.make }

        it 'updates the last operation of the service instance to the new state' do
          updater_lock.synchronous_unlock!
          expect(service_instance.last_operation.state).to eq 'succeeded'
        end
      end

      describe 'unlocking with a delayed job' do
        it 'enqueues the job' do
          job = Jobs::Services::ServiceInstanceStateFetch.new(nil, nil, nil, nil, nil)
          updater_lock.enqueue_unlock!(job)
          expect(Delayed::Job.first).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch
        end
      end
    end

    describe 'tracking if unlock is needed' do
      it 'is false by default' do
        expect(updater_lock).not_to be_needs_unlock
      end

      describe 'after it is locked' do
        before do
          updater_lock.lock!
        end

        it 'is true' do
          expect(updater_lock).to be_needs_unlock
        end

        it 'is false if you unlock and fail' do
          updater_lock.unlock_and_fail!
          expect(updater_lock).not_to be_needs_unlock
        end

        it 'is false if you synchronous unlock' do
          updater_lock.synchronous_unlock!
          expect(updater_lock).not_to be_needs_unlock
        end

        it 'is false if you enqueue an unlock' do
          job = double(Jobs::Services::ServiceInstanceStateFetch)
          updater_lock.enqueue_unlock!(job)
          expect(updater_lock).not_to be_needs_unlock
        end
      end
    end
  end
end
