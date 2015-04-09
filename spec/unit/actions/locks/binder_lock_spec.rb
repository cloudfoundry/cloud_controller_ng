require 'spec_helper'
require 'actions/locks/binder_lock'

module VCAP::CloudController
  describe BinderLock do
    let(:service_instance) { ManagedServiceInstance.make }
    let(:binder_lock) { BinderLock.new(service_instance) }

    before do
      service_instance.service_instance_operation = ServiceInstanceOperation.make(state: 'override me')
    end

    describe 'locking' do
      before do
        binder_lock.lock!
      end

      it 'sets the last operation of the service instance to "in progress"' do
        expect(service_instance.last_operation.state).to eq('in progress')
      end

      it 'sets the last operation type to "update"' do
        expect(service_instance.last_operation.type).to eq('update')
      end

      it 'does not let you lock again' do
        expect {
          binder_lock.lock!
        }.to raise_error Errors::ApiError
      end
    end

    describe 'unlocking' do
      describe 'unlocking and succeeding' do
        let(:new_service_plan) { ServicePlan.make }

        it 'reverts the last operation to whatever it was before the lock' do
          binder_lock.lock!

          expect(service_instance.last_operation.state).to eq 'in progress'
          binder_lock.unlock_and_revert_operation!
          expect(service_instance.last_operation.state).to eq 'override me'
        end

        context 'when the last operation is nil' do
          before do
            service_instance.service_instance_operation = nil
          end

          it 'reverts last operation to nil' do
            binder_lock.lock!

            expect(service_instance.last_operation.state).to eq 'in progress'
            binder_lock.unlock_and_revert_operation!
            expect(service_instance.last_operation).to be_nil
          end
        end
      end

      describe 'tracking if unlock is needed' do
        it 'is false by default' do
          expect(binder_lock.needs_unlock?).to be_falsey
        end

        describe 'after it is locked' do
          before do
            binder_lock.lock!
          end

          it 'is true' do
            expect(binder_lock.needs_unlock?).to be_truthy
          end

          it 'is false if you unlock and succeed' do
            binder_lock.unlock_and_revert_operation!
            expect(binder_lock.needs_unlock?).to be_falsey
          end
        end
      end
    end
  end
end
