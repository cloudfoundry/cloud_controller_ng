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
        expect {
          updater_lock.lock!
        }.to raise_error CloudController::Errors::ApiError
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
          expect {
            updater_lock.unlock_and_fail!
          }.to_not change { service_instance.updated_at }
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
          job = Jobs::Services::ServiceInstanceStateFetch.new(nil, nil, nil, nil, nil, nil)
          updater_lock.enqueue_unlock!(job)
          expect(Delayed::Job.first).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch
        end
      end
    end

    describe 'tracking if unlock is needed' do
      it 'is false by default' do
        expect(updater_lock.needs_unlock?).to be_falsey
      end

      describe 'after it is locked' do
        before do
          updater_lock.lock!
        end

        it 'is true' do
          expect(updater_lock.needs_unlock?).to be_truthy
        end

        it 'is false if you unlock and fail' do
          updater_lock.unlock_and_fail!
          expect(updater_lock.needs_unlock?).to be_falsey
        end

        it 'is false if you synchronous unlock' do
          updater_lock.synchronous_unlock!
          expect(updater_lock.needs_unlock?).to be_falsey
        end

        it 'is false if you enqueue an unlock' do
          job = double(Jobs::Services::ServiceInstanceStateFetch)
          updater_lock.enqueue_unlock!(job)
          expect(updater_lock.needs_unlock?).to be_falsey
        end
      end
    end
  end
end
