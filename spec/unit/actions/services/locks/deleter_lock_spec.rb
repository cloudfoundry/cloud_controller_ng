require 'spec_helper'
require 'actions/services/locks/deleter_lock'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::DeleterLock do
    let(:service_instance) { ManagedServiceInstance.make }
    let(:deleter_lock) { DeleterLock.new service_instance }
    let(:operation) { ServiceInstanceOperation.make(state: 'override me') }

    # in MySQL, milliseconds will get truncated, so to make the test
    # deterministic we need to truncate them in the setup as well,
    # so that we can compare the date in memory to the date loaded
    # from the database
    let(:previous_operation_time) { 10.seconds.ago.change(usec: 0) }

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
    end

    describe 'locking again' do
      context 'when previous operation is not create in progress' do
        let(:operation) do
          ServiceInstanceOperation.make(
            state: 'in progress',
            type: 'NOT create',
          )
        end

        it 'does not let you lock again' do
          expect {
            DeleterLock.new(service_instance).lock!
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end

      context 'when previous operation is create in progress' do
        let(:operation) do
          ServiceInstanceOperation.make(
            state: 'in progress',
            type: 'create',
          )
        end

        it 'lets you lock again' do
          expect {
            DeleterLock.new(service_instance).lock!
          }.not_to raise_error
        end
      end

      context 'when previous operation is create not in progress' do
        let(:operation) do
          ServiceInstanceOperation.make(
            state: 'NOT in progress',
            type: 'create',
          )
        end

        it 'lets you lock again' do
          expect {
            DeleterLock.new(service_instance).lock!
          }.not_to raise_error
        end
      end
    end

    describe 'unlocking' do
      describe 'unlocking and failing' do
        before do
          deleter_lock.lock!
          @operation_id_after_lock = service_instance.last_operation.reload.id
          deleter_lock.unlock_and_fail!
        end

        context 'when previous operation did not exist' do
          let(:operation) { nil }

          it 'sets the last operation of the service instance to delete failed' do
            expect(service_instance.last_operation.type).to eq('delete')
            expect(service_instance.last_operation.state).to eq('failed')
          end

          it 'visibly unlocks' do
            expect(deleter_lock.needs_unlock?).to be_falsey
          end
        end

        context 'when previous operation is create and NOT in progress' do
          let(:operation) do
            ServiceInstanceOperation.make(
              state: 'NOT in progress',
              type: 'create',
            )
          end

          it 'sets the last operation of the service instance to delete failed' do
            expect(service_instance.last_operation.type).to eq('delete')
            expect(service_instance.last_operation.state).to eq('failed')
          end

          it 'visibly unlocks' do
            expect(deleter_lock.needs_unlock?).to be_falsey
          end
        end

        context 'when previous operation is create and in progress' do
          let(:operation) do
            ServiceInstanceOperation.make(
              state: 'in progress',
              type: 'create',
              created_at: previous_operation_time
            )
          end

          it 'sets the last operation of the service instance to create in progress' do
            expect(service_instance.last_operation.type).to eq('create')
            expect(service_instance.last_operation.state).to eq('in progress')
          end

          it 'retains created_at from the previous operation' do
            expect(service_instance.last_operation.created_at).to eq(previous_operation_time)
          end

          it 'updates the operation created during locking instead of creating new one' do
            expect(service_instance.last_operation.id).to eq(@operation_id_after_lock)
          end

          it 'visibly unlocks' do
            expect(deleter_lock.needs_unlock?).to be_falsey
          end
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
          deleter_lock.enqueue_and_unlock!({ last_operation: { description: new_description } }, job)
          expect(service_instance.last_operation.description).to eq new_description
        end

        it 'enqueues the job' do
          job = Jobs::Services::ServiceInstanceStateFetch.new(nil, nil, nil, nil, nil)
          deleter_lock.enqueue_and_unlock!({}, job)
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
          deleter_lock.enqueue_and_unlock!({}, job)
          expect(deleter_lock.needs_unlock?).to be_falsey
        end
      end
    end
  end
end
