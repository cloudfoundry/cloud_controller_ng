require 'spec_helper'
require 'actions/services/locks/deleter_lock'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::DeleterLock do
    let(:service_instance) { ManagedServiceInstance.make }
    let(:deleter_lock) { DeleterLock.new service_instance }
    let(:operation) { ServiceInstanceOperation.make(state: 'override me') }

    before do
      service_instance.service_instance_operation = operation
    end

    describe 'locking' do
      before do
        deleter_lock.lock!
      end

      it 'creates a new service instance operation' do
        expect(service_instance.last_operation.guid).not_to eq(operation.guid)
      end

      it 'sets the last operation of the service instance to "in progress"' do
        expect(service_instance.last_operation.state).to eq('in progress')
      end

      it 'sets the last operation type to "delete"' do
        expect(service_instance.last_operation.type).to eq('delete')
      end

      it 'does not let you lock again' do
        expect {
          deleter_lock.lock!
        }.to raise_error CloudController::Errors::ApiError
      end
    end

    describe 'unlocking' do
      describe 'unlocking and failing' do
        before do
          deleter_lock.unlock_and_fail!
        end

        it 'sets the last operation of the service instance to "failed"' do
          expect(service_instance.last_operation.state).to eq('failed')
        end

        it 'sets the last operation type to "delete"' do
          expect(service_instance.last_operation.type).to eq('delete')
        end
      end

      describe 'unlocking and destroying' do
        it 'destroys the service instance' do
          expect(service_instance.exists?).to be_truthy
          deleter_lock.unlock_and_destroy!
          expect(service_instance.exists?).to be_falsey
        end

        it 'destroys the last operation of the service instance' do
          expect(service_instance.last_operation.exists?).to be_truthy
          deleter_lock.unlock_and_destroy!
          expect(service_instance.last_operation.exists?).to be_falsey
        end
      end

      describe 'unlocking with a delayed job' do
        it 'updates the attributes on the service instance' do
          job = instance_double(Jobs::Services::ServiceInstanceStateFetch)
          new_description = 'new description'
          deleter_lock.enqueue_unlock!({ last_operation: { description: new_description } }, job)
          expect(service_instance.last_operation.description).to eq new_description
        end

        it 'enqueues the job' do
          job = Jobs::Services::ServiceInstanceStateFetch.new(nil, nil, nil, nil, nil)
          deleter_lock.enqueue_unlock!({}, job)
          expect(Delayed::Job.first).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch
        end
      end
    end

    describe 'tracking if unlock is needed' do
      it 'is false by default' do
        expect(deleter_lock.needs_unlock?).to be_falsey
      end

      describe 'after it is locked' do
        before do
          deleter_lock.lock!
        end

        it 'is true' do
          expect(deleter_lock.needs_unlock?).to be_truthy
        end

        it 'is false if you unlock and fail' do
          deleter_lock.unlock_and_fail!
          expect(deleter_lock.needs_unlock?).to be_falsey
        end

        it 'is false if you unlock and destroy' do
          deleter_lock.unlock_and_destroy!
          expect(deleter_lock.needs_unlock?).to be_falsey
        end

        it 'is false if you enqueue an unlock' do
          job = double(Jobs::Services::ServiceInstanceStateFetch)
          deleter_lock.enqueue_unlock!({}, job)
          expect(deleter_lock.needs_unlock?).to be_falsey
        end
      end
    end
  end
end
