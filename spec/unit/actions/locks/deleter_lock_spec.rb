require 'spec_helper'
require 'actions/locks/deleter_lock'

module VCAP::CloudController
  describe VCAP::CloudController::DeleterLock do
    describe 'tracking if unlock is needed' do
      let(:service_instance) { ManagedServiceInstance.make }
      let(:deleter_lock) { DeleterLock.new service_instance }

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
