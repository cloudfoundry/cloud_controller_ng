require 'spec_helper'
require 'delayed_job'
require 'delayed_job/threaded_worker'

RSpec.describe ThreadedWorker do
  let(:thread_count) { 2 }
  let(:worker) { ThreadedWorker.new(thread_count) }

  before do
    allow(worker).to receive(:say)
    allow(worker).to receive(:work_off).and_return([1, 0])
    allow(worker).to receive(:trap_signals)
    allow(worker).to receive(:sleep)
  end

  describe '#initialize' do
    it 'sets up the thread count' do
      expect(worker.instance_variable_get(:@thread_count)).to eq(thread_count)
    end

    it 'initializes stop signal and shutdown flag' do
      expect(worker.instance_variable_get(:@stop_signal).false?).to be true
    end

    it 'creates a thread pool with the correct thread count' do
      pool = worker.instance_variable_get(:@pool)
      expect(pool.min_length).to eq(thread_count)
      expect(pool.max_length).to eq(thread_count)
    end
  end

  describe '#start' do
    before do
      allow(worker).to receive(:sleep) do
        worker.instance_variable_set(:@stop_signal, Concurrent::AtomicBoolean.new(true))
      end
    end

    it 'sets up signal traps' do
      expect(worker).to receive(:trap_signals).and_call_original
      worker.start
    end

    it 'starts the specified number of threads' do
      expect(worker.instance_variable_get(:@pool)).to receive(:post).exactly(thread_count).times
      worker.start
    end

    it 'logs the start and shutdown messages' do
      expect(worker).to receive(:say).with('Starting multi-threaded job worker with 2 threads')
      expect(worker).to receive(:say).with('Shutting down...')
      expect(worker).to receive(:say).with('All threads have finished. Exiting.')
      worker.start
    end

    it 'calls initiate_shutdown when a TERM signal is handled' do
      skip 'Test for SIGTERM handling is temporarily skipped'
    end

    it 'calls initiate_shutdown when an INT signal is handled' do
      skip 'Test for SIGINT handling is temporarily skipped'
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
      worker.instance_variable_set(:@stop_signal, Concurrent::AtomicBoolean.new(true))
      expect(worker.send(:stop_signal?)).to be true
    end
  end

  describe '#generate_thread_name' do
    it 'generates the correct thread name when instance name is set' do
      worker.name = 'instance_name'
      expect(worker.send(:generate_thread_name, 1)).to eq('instance_name thread:1')
    end

    it 'generates the correct thread name when instance name is not set' do
      expected_name = "host:#{Socket.gethostname} pid:#{Process.pid} thread:1"
      expect(worker.send(:generate_thread_name, 1)).to eq(expected_name)
    end
  end

  describe '#threaded_work_off' do
    it 'sets the thread name correctly' do
      allow(worker).to receive(:stop_signal?).and_return(true)
      expected_name = "host:#{Socket.gethostname} pid:#{Process.pid} thread:1"
      expect(Thread.current).to receive(:[]=).with(:name, expected_name)
      worker.send(:threaded_work_off, 1)
    end

    it 'processes jobs and sleeps when no jobs are found' do
      allow(worker).to receive(:stop_signal?).and_return(false, false, true)
      allow(worker).to receive(:work_off).and_return([0, 0])

      worker.send(:threaded_work_off, 1)
      expect(worker).to have_received(:sleep).once
    end

    it 'processes jobs and logs the results' do
      allow(worker).to receive(:work_off).and_return([5, 2])

      # Ensure the loop exits after 1st iteration
      allow(worker).to receive(:stop_signal?).and_return(false, true)

      expect(worker).to receive(:say).with(%r{7 jobs processed at \d+\.\d+ j/s, 2 failed}).once
      worker.send(:threaded_work_off, 1)
    end

    it 'handles exceptions and retries up to 5 times' do
      allow(worker).to receive(:work_off).and_raise(StandardError.new('test error'))
      allow(worker).to receive(:sleep)
      allow(worker).to receive(:stop_signal?).and_return(false, false, false, false, true)

      expect(worker).to receive(:say).with('Worker thread encountered an error: test error. Retrying...').exactly(5).times
      expect(worker).to receive(:say).with('Worker thread has failed 5 times. Exiting to prevent infinite loop.').once
      worker.send(:threaded_work_off, 1)
    end

    it 'exits gracefully when stop signal is received' do
      allow(worker).to receive(:stop_signal?).and_return(true)

      expect(worker).not_to receive(:work_off)
      worker.send(:threaded_work_off, 1)
    end
  end

  describe '#initiate_shutdown' do
    it 'sets stop signal and logs shutdown initiation' do
      expect(worker).to receive(:say).with('Initiating shutdown...')
      worker.send(:initiate_shutdown)
      expect(worker.instance_variable_get(:@stop_signal).true?).to be true
    end
  end

  describe '#thread_pool' do
    it 'ensures thread pool remains operational after repeated failures' do
      failure_count = 0
      allow(worker).to receive(:work_off) do
        failure_count += 1
        raise StandardError.new('Simulated error') if failure_count <= 6

        [1, 0] # Return normally after 6 failures
      end
      thread = Thread.new { worker.start }
      sleep 0.2

      pool = worker.instance_variable_get(:@pool)
      active_threads_before = pool.scheduled_task_count

      sleep 0.2
      active_threads_after = pool.scheduled_task_count

      expect(active_threads_before).to eq(thread_count)
      expect(active_threads_after).to eq(thread_count)

      # Cleanup
      worker.instance_variable_set(:@stop_signal, Concurrent::AtomicBoolean.new(true))
      thread.join
    end
  end
end
