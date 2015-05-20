require 'spec_helper'

module VCAP::CloudController
  describe UpdaterLock do
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
        }.to raise_error Errors::ApiError
      end
    end

    describe 'unlocking' do
      describe 'unlocking and failing' do
        before do
          updater_lock.unlock_and_fail!
        end

        it 'sets the last operation of the service instance to "failed"' do
          expect(service_instance.last_operation.state).to eq('failed')
        end

        it 'sets the last operation type to "update"' do
          expect(service_instance.last_operation.type).to eq('update')
        end
      end

      describe 'unlocking synchronously' do
        let(:new_service_plan) { ServicePlan.make }
        it 'updates the service instance' do
          old_service_plan = service_instance.service_plan
          expect {
            updater_lock.synchronous_unlock!(service_plan_id: new_service_plan.id)
          }.to change { service_instance.service_plan }.from(old_service_plan).to(new_service_plan)
        end

        it 'updates the last operation of the service instance to the new state' do
          updater_lock.synchronous_unlock!(
            last_operation: {
              state: 'succeeded'
            }
          )
          expect(service_instance.last_operation.state).to eq 'succeeded'
        end
      end

      describe 'unlocking with a delayed job' do
        it 'updates the attributes on the service instance' do
          job = double(Jobs::Services::ServiceInstanceStateFetch)
          new_description = 'new description'
          updater_lock.enqueue_unlock!({ last_operation: { description: new_description } }, job)
          expect(service_instance.last_operation.description).to eq new_description
        end

        it 'enqueues the job' do
          job = Jobs::Services::ServiceInstanceStateFetch.new(nil, nil, nil, nil, nil)
          updater_lock.enqueue_unlock!({}, job)
          expect(Delayed::Job.first).to be_a_fully_wrapped_job_of Jobs::Services::ServiceInstanceStateFetch
        end
      end
    end
  end
end
