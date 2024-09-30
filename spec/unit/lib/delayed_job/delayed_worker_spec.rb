require 'spec_helper'
require 'tasks/rake_config'
require 'delayed_job/delayed_worker'

RSpec.describe CloudController::DelayedWorker do
  let(:options) { { queues: 'default', name: 'test_worker' } }
  let(:environment) { instance_double(BackgroundJobEnvironment, setup_environment: nil) }
  let(:delayed_worker) { instance_double(Delayed::Worker, start: nil) }
  let(:threaded_worker) { instance_double(Delayed::ThreadedWorker, start: nil) }

  before do
    allow(RakeConfig).to receive(:config).and_return(TestConfig.config_instance)
    allow(BackgroundJobEnvironment).to receive(:new).with(anything).and_return(environment)
    allow(Delayed::Worker).to receive(:new).and_return(delayed_worker)
    allow(delayed_worker).to receive(:name=).with(anything)
    allow(Delayed::ThreadedWorker).to receive(:new).and_return(threaded_worker)
    allow(threaded_worker).to receive(:name=).with(anything)
  end

  describe '#initialize' do
    it 'sets the correct queue options' do
      worker_instance = CloudController::DelayedWorker.new(options)
      expect(worker_instance.instance_variable_get(:@queue_options)).to eq({
                                                                             min_priority: nil,
                                                                             max_priority: nil,
                                                                             queues: 'default',
                                                                             worker_name: 'test_worker',
                                                                             quiet: true
                                                                           })
    end
  end

  describe '#start_working' do
    let(:cc_delayed_worker) { CloudController::DelayedWorker.new(options) }

    it 'sets up the environment and starts the worker' do
      expect(environment).to receive(:setup_environment).with(nil)
      expect(Delayed::Worker).to receive(:new).with(anything).and_return(delayed_worker)
      expect(delayed_worker).to receive(:start)

      cc_delayed_worker.start_working
    end

    it 'configures Delayed::Worker settings' do
      cc_delayed_worker.start_working

      expect(Delayed::Worker.destroy_failed_jobs).to be false
      expect(Delayed::Worker.max_attempts).to eq(3)
      expect(Delayed::Worker.max_run_time).to eq(14_401)
    end

    context 'when the number of threads is specified' do
      before do
        allow(Delayed).to receive(:remove_const).with(:Worker)
        allow(Delayed).to receive(:const_set).with(:Worker, Delayed::ThreadedWorker)

        TestConfig.config[:jobs].merge!(number_of_worker_threads: 7)
      end

      it 'creates a ThreadedWorker with the specified number of threads' do
        expect(Delayed).to receive(:remove_const).with(:Worker).once
        expect(Delayed).to receive(:const_set).with(:Worker, Delayed::ThreadedWorker).once
        expect(environment).to receive(:setup_environment).with(nil)
        expect(Delayed::Worker).to receive(:new).with({ max_priority: nil, min_priority: nil, num_threads: 7, queues: 'default', quiet: true,
                                                        worker_name: 'test_worker' }).and_return(threaded_worker)
        expect(threaded_worker).to receive(:name=).with('test_worker')
        expect(threaded_worker).to receive(:start)

        cc_delayed_worker.start_working
      end
    end
  end

  describe '#clear_locks!' do
    let(:cc_delayed_worker) { CloudController::DelayedWorker.new(options) }

    context 'when Delayed::Worker is used' do
      it 'clears the locks' do
        expect(environment).to receive(:setup_environment).with(nil)
        expect(Delayed::Worker).to receive(:new).with(anything).and_return(delayed_worker)
        expect(delayed_worker).to receive(:name=).with('test_worker')
        expect(delayed_worker).to receive(:name).and_return('test_worker')
        expect(Delayed::Job).to receive(:clear_locks!).with('test_worker')

        cc_delayed_worker.clear_locks!
      end
    end

    context 'when Delayed::ThreadedWorker is used' do
      it 'clears the locks for all threads' do
        expect(environment).to receive(:setup_environment).with(nil)
        expect(Delayed::Worker).to receive(:new).with(anything).and_return(threaded_worker)
        expect(threaded_worker).to receive(:name=).with('test_worker')
        expect(threaded_worker).to receive(:name).and_return('test_worker')
        expect(threaded_worker).to receive(:names_with_threads).and_return(['test_worker thread:1', 'test_worker thread:2'])
        expect(Delayed::Job).to receive(:clear_locks!).with('test_worker').once
        expect(Delayed::Job).to receive(:clear_locks!).with('test_worker thread:1').once
        expect(Delayed::Job).to receive(:clear_locks!).with('test_worker thread:2').once

        cc_delayed_worker.clear_locks!
      end
    end
  end
end
