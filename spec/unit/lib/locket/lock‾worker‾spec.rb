require 'spec_helper'
require 'locket/lock_worker'
require 'locket/lock_runner'

RSpec.describe Locket::LockWorker do
  let(:lock_runner) { instance_double(Locket::LockRunner, start: nil, lock_acquired?: nil) }
  subject(:lock_worker) { Locket::LockWorker.new(lock_runner) }

  describe '#acquire_lock_and' do
    before do
      # `loop` is an instance method on Object. Who knew?
      allow(lock_worker).to receive(:loop).and_yield
      allow(lock_worker).to receive(:sleep) # dont use real time please
    end

    it 'should start the LockRunner' do
      lock_worker.acquire_lock_and_repeatedly_call {}

      expect(lock_runner).to have_received(:start)
    end

    describe 'when it does not have the lock' do
      it 'does not yield to the block if it does not have the lock' do
        allow(lock_runner).to receive(:lock_acquired?).and_return(false)

        expect { |b| lock_worker.acquire_lock_and_repeatedly_call(&b) }.not_to yield_control
      end

      it 'sleeps before attempting to check the lock status again' do
        allow(lock_runner).to receive(:lock_acquired?).and_return(false)

        lock_worker.acquire_lock_and_repeatedly_call {}
        expect(lock_worker).to have_received(:sleep).with(1)
      end
    end

    describe 'when it does not have the lock' do
      it 'yields to the block if it does have the lock' do
        allow(lock_runner).to receive(:lock_acquired?).and_return(true)

        expect { |b| lock_worker.acquire_lock_and_repeatedly_call(&b) }.to yield_control
      end
    end
  end
end
