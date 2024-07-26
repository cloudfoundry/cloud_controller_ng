require 'spec_helper'
require 'tasks/rake_config'
require 'delayed_job/delayed_worker'

RSpec.describe CloudController::DelayedWorker do
  let(:options) { { queues: 'default', name: 'test_worker' } }
  let(:environment) { instance_double(BackgroundJobEnvironment, setup_environment: nil) }
  let(:delayed_worker) { instance_double(Delayed::Worker, start: nil) }
  let(:threaded_worker) { instance_double(ThreadedWorker, start: nil) }

  before do
    allow(RakeConfig).to receive(:config).and_return(TestConfig.config_instance)
    allow(BackgroundJobEnvironment).to receive(:new).with(anything).and_return(environment)
    allow(Delayed::Worker).to receive(:new).and_return(delayed_worker)
    allow(delayed_worker).to receive(:name=).with(anything)
    allow(ThreadedWorker).to receive(:new).and_return(threaded_worker)
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
      expect(delayed_worker).to receive(:name=).with('test_worker')
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
      before { TestConfig.config[:jobs].merge!(threads: 7) }

      it 'creates a ThreadedWorker with the specified number of threads' do
        expect(environment).to receive(:setup_environment).with(nil)
        expect(ThreadedWorker).to receive(:new).with(7, anything).and_return(threaded_worker)
        expect(threaded_worker).to receive(:name=).with('test_worker')
        expect(threaded_worker).to receive(:start)

        cc_delayed_worker.start_working
      end
    end
  end
end
