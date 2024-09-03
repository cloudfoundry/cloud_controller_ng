require 'spec_helper'
require 'delayed_job'
require 'delayed_job/threaded_worker'

RSpec.describe ThreadedWorker do
  let(:num_threads) { 2 }
  let(:grace_period_seconds) { 2 }
  let(:worker) { ThreadedWorker.new(num_threads, {}, grace_period_seconds) }
  let(:worker_name) { 'instance_name' }

  before { worker.name = worker_name }

  describe '#initialize' do
    it 'sets up the thread count' do
      expect(worker.instance_variable_get(:@num_threads)).to eq(num_threads)
    end

    it 'sets up the grace period' do
      expect(worker.instance_variable_get(:@grace_period_seconds)).to eq(grace_period_seconds)
    end

    it 'sets up the grace period to 30 seconds by default' do
      worker = ThreadedWorker.new(num_threads)
      expect(worker.instance_variable_get(:@grace_period_seconds)).to eq(30)
    end
  end

  describe '#start' do
    before do
      allow(worker).to receive(:threaded_start)
    end

    it 'sets up signal traps for all signals' do
      expect(worker).to receive(:trap).with('TERM')
      expect(worker).to receive(:trap).with('INT')
      expect(worker).to receive(:trap).with('QUIT')
      worker.start
    end

    it 'starts the specified number of threads' do
      expect(worker).to receive(:threaded_start).exactly(num_threads).times

      expect(worker.instance_variable_get(:@threads).length).to eq(0)
      worker.start
      expect(worker.instance_variable_get(:@threads).length).to eq(num_threads)
    end

    it 'logs the start and shutdown messages' do
      expect(worker).to receive(:say).with("Starting threaded delayed worker with #{num_threads} threads")
      worker.start
    end

    it 'sets the thread_name variable for each thread' do
      worker.start
      worker.instance_variable_get(:@threads).each_with_index do |thread, index|
        expect(thread[:thread_name]).to eq("thread:#{index + 1}")
      end
    end

    it 'logs the error and stops the worker when an unexpected error occurs' do
      allow(worker).to receive(:threaded_start).and_raise(StandardError.new('test error'))
      allow(worker).to receive(:stop)
      expect { worker.start }.to raise_error('Unexpected error occurred in one of the worker threads')
      expect(worker.instance_variable_get(:@unexpected_error)).to be true
    end
  end

  describe '#name' do
    it 'returns the instance name if thread name is set' do
      allow(Thread.current).to receive(:[]).with(:thread_name).and_return('some-thread-name')
      expect(worker.name).to eq('instance_name some-thread-name')
    end

    it 'returns the instance name if thread name is not set' do
      allow(Thread.current).to receive(:[]).with(:thread_name).and_return(nil)
      expect(worker.name).to eq(worker_name)
    end
  end

  describe '#stop' do
    it 'logs the shutdown message' do
      queue = Queue.new
      allow(worker).to(receive(:say)) { |message| queue.push(message) }

      worker.stop
      expect(queue.pop).to eq('Shutting down worker threads gracefully...')
    end

    it 'sets the exit flag in the parent worker' do
      worker.stop
      sleep 0.1 until worker.instance_variable_defined?(:@exit)
      expect(worker.instance_variable_get(:@exit)).to be true
    end

    it 'allows threads to finish their work without being killed prematurely' do
      allow(worker).to receive(:threaded_start) do
        5.times { sleep grace_period_seconds / 2 until worker.instance_variable_get(:@exit) == true }
      end

      worker_thread = Thread.new { worker.start }
      sleep 0.1 until worker.instance_variable_get(:@threads).length == num_threads && worker.instance_variable_get(:@threads).all?(&:alive?)
      worker.instance_variable_get(:@threads).each { |t| allow(t).to receive(:kill).and_call_original }

      Thread.new { worker.stop }.join
      worker_thread.join
      worker.instance_variable_get(:@threads).each { |t| expect(t).not_to have_received(:kill) }
    end

    it 'kills threads that exceed the grace period during shutdown' do
      worker = ThreadedWorker.new(num_threads, {}, 3)
      allow(worker).to receive(:threaded_start) do
        10.times { sleep grace_period_seconds * 2 until worker.instance_variable_get(:@exit) == true }
      end

      worker_thread = Thread.new { worker.start }
      sleep 0.1 until worker.instance_variable_get(:@threads).length == num_threads && worker.instance_variable_get(:@threads).all?(&:alive?)
      worker.instance_variable_get(:@threads).each { |t| allow(t).to receive(:kill).and_call_original }

      Thread.new { worker.stop }.join
      worker_thread.join
      expect(worker.instance_variable_get(:@threads)).to all(have_received(:kill))
    end
  end

  describe '#threaded_start' do
    before do
      allow(worker).to receive(:work_off).and_return([5, 2])
      allow(worker).to receive(:sleep)
      allow(worker).to receive(:stop?).and_return(false, true)
      allow(worker).to receive(:reload!).and_call_original
    end

    it 'runs the work_off loop twice' do
      worker.threaded_start
      expect(worker).to have_received(:work_off).twice
    end

    it 'logs the number of jobs processed' do
      expect(worker).to receive(:say).with(%r{7 jobs processed at \d+\.\d+ j/s, 2 failed}).twice
      worker.threaded_start
    end

    it 'reloads the worker if stop is not set' do
      allow(worker).to receive(:work_off).and_return([0, 0])
      worker.threaded_start
      expect(worker).to have_received(:reload!).once
    end

    context 'when exit_on_complete is set' do
      before do
        allow(worker.class).to receive(:exit_on_complete).and_return(true)
        allow(worker).to receive(:work_off).and_return([0, 0])
      end

      it 'exits the worker when no more jobs are available' do
        expect(worker).to receive(:say).with('No more jobs available. Exiting')
        worker.threaded_start
      end
    end
  end
end
