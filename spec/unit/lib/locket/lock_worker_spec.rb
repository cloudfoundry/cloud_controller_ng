require 'spec_helper'
require 'locket/lock_worker'
require 'locket/client'

RSpec.describe Locket::LockWorker do
  let(:client) { instance_double(Locket::Client, start: nil, lock_acquired?: nil) }
  let(:key) { 'lock-key' }
  let(:owner) { 'lock-owner' }
  subject(:lock_worker) { Locket::LockWorker.new(client) }

  describe '#acquire_lock_and' do
    before do
      # `loop` is an instance method on Object. Who knew?
      allow(lock_worker).to receive(:loop).and_yield
      allow(lock_worker).to receive(:sleep) # dont use real time please
    end

    it 'should start the Client' do
      lock_worker.acquire_lock_and_repeatedly_call(owner: owner, key: key, &{})

      expect(client).to have_received(:start).with(owner: owner, key: key)
    end

    describe 'when it does not have the lock' do
      it 'does not yield to the block' do
        allow(client).to receive(:lock_acquired?).and_return(false)

        expect { |b| lock_worker.acquire_lock_and_repeatedly_call(owner: owner, key: key, &b) }.not_to yield_control
      end

      it 'sleeps before attempting to check the lock status again' do
        allow(client).to receive(:lock_acquired?).and_return(false)

        lock_worker.acquire_lock_and_repeatedly_call(owner: owner, key: key, &{})
        expect(lock_worker).to have_received(:sleep).with(1)
      end
    end

    describe 'when it does have the lock' do
      it 'yields to the block' do
        allow(client).to receive(:lock_acquired?).and_return(true)

        expect { |b| lock_worker.acquire_lock_and_repeatedly_call(owner: owner, key: key, &b) }.to yield_control
      end
    end
  end
end
