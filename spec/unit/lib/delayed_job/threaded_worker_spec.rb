require 'spec_helper'
require 'delayed_job'
require 'delayed_job/threaded_worker'

RSpec.describe ThreadedWorker do
  let(:options) { { worker_name: 'test_worker' } }
  let(:thread_count) { 2 }
  let(:worker) { ThreadedWorker.new(thread_count, options) }

  describe '#initialize' do
    it 'initializes with given options and thread count' do
      expect(worker.instance_variable_get(:@thread_count)).to eq(thread_count)
      expect(worker.instance_variable_get(:@name_prefix)).to eq('test_worker')
    end
  end

  describe '#start' do
    before do
      allow(worker).to receive(:trap_signals)
      allow(worker).to receive(:say)
      allow(worker).to receive(:threaded_work_off)
    end

    it 'starts the specified number of threads' do
      expect(Thread).to receive(:new).exactly(thread_count).times.and_call_original
      worker.start
      expect(worker.instance_variable_get(:@threads).size).to eq(thread_count)
    end
  end

  describe '#name' do
    it 'returns the current thread name if set' do
      Thread.current[:name] = 'thread_name'
      expect(worker.name).to eq('thread_name')
    end

    it 'returns the instance name if thread name is not set' do
      worker.name = 'instance_name'
      expect(worker.name).to eq('instance_name')
    end
  end

  describe '#name=' do
    it 'sets the name for the instance and thread-local storage' do
      worker.name = 'new_name'
      expect(worker.instance_variable_get(:@name)).to eq('new_name')
      expect(Thread.current[:name]).to eq('new_name')
    end
  end

  describe '#stop_signal?' do
    it 'returns the value of the stop signal' do
      worker.instance_variable_set(:@stop_signal, true)
      expect(worker.send(:stop_signal?)).to be true
    end
  end

  describe '#generate_thread_name' do
    it 'generates the correct thread name when instance name is set' do
      worker.name = 'instance_name'
      expect(worker.send(:generate_thread_name, 1)).to eq('instance_name-thread:1')
    end

    it 'generates the correct thread name when instance name is not set' do
      hostname = Socket.gethostname
      pid = Process.pid
      expected_name = "test_worker-host:#{hostname} pid:#{pid} thread:1"
      expect(worker.send(:generate_thread_name, 1)).to eq(expected_name)
    end
  end

  describe '#threaded_work_off' do
    before do
      allow(worker).to receive(:say)
      allow(worker).to receive(:sleep).and_return(nil)
      allow(ThreadedWorker).to receive(:sleep_delay).and_return(0)
    end

    it 'processes jobs and sleeps when no jobs are found' do
      allow(worker).to receive(:work_off).and_return([0, 0])

      # Ensure the loop exits after 2nd iteration
      allow(worker).to receive(:stop_signal?).and_return(false, false, true)

      worker.send(:threaded_work_off)
      expect(worker).to have_received(:sleep).with(0)
    end

    it 'processes jobs and logs the results' do
      allow(worker).to receive(:work_off).and_return([5, 2])

      # Ensure the loop exits after 1st iteration
      allow(worker).to receive(:stop_signal?).and_return(false, true)

      expect(worker).to receive(:say).with(%r{7 jobs processed at \d+\.\d+ j/s, 2 failed}).once
      worker.send(:threaded_work_off)
    end

    it 'handles exceptions and retries up to 5 times' do
      allow(worker).to receive(:work_off).and_raise(StandardError.new('test error'))
      allow(worker).to receive(:sleep)

      # Ensure the loop exits after 5th iteration
      allow(worker).to receive(:stop_signal?).and_return(false, false, false, false, true)

      expect(worker).to receive(:say).with(/Thread .* encountered an error: test error. Restarting thread.../).exactly(5).times
      expect(worker).to receive(:say).with(/Thread .* has failed 5 times. Exiting to prevent infinite loop./).once
      worker.send(:threaded_work_off)
    end

    it 'exits gracefully when stop signal is received' do
      # Ensure the loop exits immediately
      allow(worker).to receive(:stop_signal?).and_return(true)

      expect(worker).to receive(:say).with('Stop signal received. Exiting.').once
      worker.send(:threaded_work_off)
    end
  end

  describe 'signal trapping' do
    before do
      allow(worker).to receive(:say)
      allow(worker).to receive(:threaded_work_off)
      allow(Thread).to receive(:new).and_call_original
    end

    it 'traps TERM and INT signals and initiates shutdown' do
      expect(worker).to receive(:trap).with('TERM').and_call_original
      expect(worker).to receive(:trap).with('INT').and_call_original
      worker.start
    end

    it 'sets stop_signal to true on shutdown' do
      allow(worker).to receive(:trap).and_call_original
      worker.start
      worker.send(:initiate_shutdown)
      expect(worker.instance_variable_get(:@stop_signal)).to be true
    end
  end
end
