require 'spec_helper'
require 'tasks/rake_config'
require 'delayed_job/delayed_worker'

RSpec.describe CloudController::DelayedWorker do
  let(:options) { { queues: 'default', name: 'test_worker' } }
  let(:environment) { instance_double(BackgroundJobEnvironment, setup_environment: nil) }
  let(:worker) { instance_double(Delayed::Worker, start: nil) }

  before do
    allow(RakeConfig).to receive(:config).and_return(TestConfig.config_instance)
    allow(BackgroundJobEnvironment).to receive(:new).with(anything).and_return(environment)
    allow(Delayed::Worker).to receive(:new).and_return(worker)
    allow(worker).to receive(:name=).with(anything)
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
    let(:worker_instance) { CloudController::DelayedWorker.new(options) }

    it 'sets up the environment and starts the worker' do
      expect(environment).to receive(:setup_environment).with(anything)
      expect(worker).to receive(:name=).with('test_worker')
      expect(worker).to receive(:start)

      worker_instance.start_working
    end

    it 'configures Delayed::Worker settings' do
      worker_instance.start_working

      expect(Delayed::Worker.destroy_failed_jobs).to be false
      expect(Delayed::Worker.max_attempts).to eq(3)
      expect(Delayed::Worker.max_run_time).to eq(14_401)
    end
  end
end
