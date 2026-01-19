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
    it 'sets the correct default queue options' do
      worker_instance = CloudController::DelayedWorker.new(options)
      expect(worker_instance.instance_variable_get(:@queue_options)).to eq({
                                                                             min_priority: nil,
                                                                             max_priority: nil,
                                                                             queues: options[:queues],
                                                                             worker_name: options[:name],
                                                                             quiet: true
                                                                           })
      expect(worker_instance.instance_variable_get(:@queue_options)).not_to include(:num_threads)
      expect(worker_instance.instance_variable_get(:@queue_options)).not_to include(:grace_period_seconds)
    end

    context 'when num_threads parameter is set' do
      before { options[:num_threads] = 5 }

      it 'sets the number of threads if specified in the queue options' do
        worker_instance = CloudController::DelayedWorker.new(options)
        expect(worker_instance.instance_variable_get(:@queue_options)).to include(num_threads: 5)
        expect(worker_instance.instance_variable_get(:@queue_options)).not_to include(:grace_period_seconds)
      end

      it 'does not set num_threads if value is not greater than 0' do
        options[:num_threads] = 0
        worker_instance = CloudController::DelayedWorker.new(options)
        expect(worker_instance.instance_variable_get(:@queue_options)).not_to include(:num_threads)
      end

      it 'sets the grace period if specified in the queue options' do
        options[:thread_grace_period_seconds] = 32
        worker_instance = CloudController::DelayedWorker.new(options)
        expect(worker_instance.instance_variable_get(:@queue_options)).to include(grace_period_seconds: 32)
      end

      it 'does not set grace_period_seconds if value is not greater than 0' do
        options[:thread_grace_period_seconds] = 0
        worker_instance = CloudController::DelayedWorker.new(options)
        expect(worker_instance.instance_variable_get(:@queue_options)).not_to include(:grace_period_seconds)
      end
    end

    it 'does not set grace_period_seconds if num_threads is not set' do
      options[:thread_grace_period_seconds] = 32
      worker_instance = CloudController::DelayedWorker.new(options)
      expect(worker_instance.instance_variable_get(:@queue_options)).not_to include(:grace_period_seconds)
    end

    describe 'publish metrics' do
      context 'when not set' do
        it 'does not publish metrics' do
          worker_instance = CloudController::DelayedWorker.new(options)
          expect(worker_instance.instance_variable_get(:@publish_metrics)).to be(false)
        end
      end

      context 'when set to true' do
        before do
          options[:publish_metrics] = true
        end

        it 'publishes metrics' do
          worker_instance = CloudController::DelayedWorker.new(options)
          expect(worker_instance.instance_variable_get(:@publish_metrics)).to be(true)
        end
      end
    end
  end

  describe '#start_working' do
    let(:cc_delayed_worker) { CloudController::DelayedWorker.new(options) }

    before do
      @steno_config_backup = Steno.config
      allow(delayed_worker).to receive(:name).and_return(options[:name])
    end

    after do
      Steno.init(@steno_config_backup)
    end

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
      expect(Delayed::Worker.sleep_delay).to eq(5)
    end

    it 'sets the worker name in the Steno context' do
      cc_delayed_worker.start_working
      expect(Steno.config.context.data[:worker_name]).to eq(options[:name])
    end

    context 'when the number of threads is specified' do
      before do
        allow(Delayed).to receive(:remove_const).with(:Worker)
        allow(Delayed).to receive(:const_set).with(:Worker, Delayed::ThreadedWorker)
        allow(threaded_worker).to receive(:name)
        options[:num_threads] = 7
      end

      it 'creates a ThreadedWorker with the specified number of threads' do
        expect(Delayed).to receive(:remove_const).with(:Worker).once
        expect(Delayed).to receive(:const_set).with(:Worker, Delayed::ThreadedWorker).once
        expect(environment).to receive(:setup_environment).with(nil)
        expect(Delayed::Worker).to receive(:new).with({ max_priority: nil, min_priority: nil, num_threads: 7, queues: options[:queues], quiet: true,
                                                        worker_name: options[:name] }).and_return(threaded_worker)
        expect(threaded_worker).to receive(:name=).with(options[:name])
        expect(threaded_worker).to receive(:start)

        cc_delayed_worker.start_working
      end

      it 'sets the grace period' do
        options[:thread_grace_period_seconds] = 32
        expect(Delayed::Worker).to receive(:new).with({ max_priority: nil, min_priority: nil, num_threads: 7, grace_period_seconds: 32, queues: options[:queues], quiet: true,
                                                        worker_name: options[:name] }).and_return(threaded_worker)
        cc_delayed_worker.start_working
      end
    end

    context 'when DB type is mysql' do
      before do
        db = instance_double(Sequel::Database)
        allow(db).to receive(:database_type).and_return(:mysql)
        allow(Sequel::Model).to receive(:db).and_return(db)
      end

      it 'read_ahead defaults to DEFAULT_READ_AHEAD_MYSQL' do
        cc_delayed_worker.start_working
        expect(Delayed::Worker.read_ahead).to eq(CloudController::DelayedWorker::DEFAULT_READ_AHEAD_MYSQL)
      end

      it 'read_ahead can be configured' do
        TestConfig.config[:jobs][:read_ahead] = 3
        cc_delayed_worker.start_working
        expect(Delayed::Worker.read_ahead).to eq(3)
      end

      it 'read_ahead cant be set to 0' do
        TestConfig.config[:jobs][:read_ahead] = 0
        cc_delayed_worker.start_working
        expect(Delayed::Worker.read_ahead).to eq(CloudController::DelayedWorker::DEFAULT_READ_AHEAD_MYSQL)
      end
    end

    context 'when DB type is postgres' do
      before do
        db = instance_double(Sequel::Database)
        allow(db).to receive(:database_type).and_return(:postgres)
        allow(Sequel::Model).to receive(:db).and_return(db)
      end

      it 'read_ahead defaults to DEFAULT_READ_AHEAD_POSTGRES' do
        cc_delayed_worker.start_working
        expect(Delayed::Worker.read_ahead).to eq(CloudController::DelayedWorker::DEFAULT_READ_AHEAD_POSTGRES)
      end

      it 'read_ahead can be configured' do
        TestConfig.config[:jobs][:read_ahead] = 3
        cc_delayed_worker.start_working
        expect(Delayed::Worker.read_ahead).to eq(3)
      end

      it 'read_ahead cant be set to negative values' do
        TestConfig.config[:jobs][:read_ahead] = -1
        cc_delayed_worker.start_working
        expect(Delayed::Worker.read_ahead).to eq(CloudController::DelayedWorker::DEFAULT_READ_AHEAD_POSTGRES)
      end
    end

    describe 'publish metrics' do
      before do
        allow(Prometheus::Client::DataStores::DirectFileStore).to receive(:new)
      end

      context 'when set to false' do
        before do
          options[:publish_metrics] = false
        end

        it 'does not publish metrics' do
          cc_delayed_worker.start_working
          expect(Prometheus::Client::DataStores::DirectFileStore).not_to have_received(:new)
        end
      end

      context 'when set to true but not in CC_WORKER context' do
        before do
          options[:publish_metrics] = true
          allow(VCAP::CloudController::ExecutionContext).to receive(:from_process_type_env).and_return(nil)
        end

        it 'raises an error' do
          expect do
            cc_delayed_worker.start_working
          end.to raise_error('Metric publishing is only supported for cc workers')
        end
      end

      context 'when set to true' do
        before do
          options[:publish_metrics] = true
          allow(VCAP::CloudController::ExecutionContext).to receive(:from_process_type_env).and_return(VCAP::CloudController::ExecutionContext::CC_WORKER)
        end

        it 'publishes metrics' do
          cc_delayed_worker.start_working
          expect(Prometheus::Client::DataStores::DirectFileStore).to have_received(:new)
        end

        it 'loads the delayed job metrics plugin' do
          cc_delayed_worker.start_working
          expect(Delayed::Worker.plugins).to include(DelayedJobMetrics::Plugin)
        end

        context 'when first worker on machine' do
          before do
            allow(cc_delayed_worker).to receive(:is_first_generic_worker_on_machine?).and_return(true)
            allow(cc_delayed_worker).to receive(:readiness_port)
            allow(cc_delayed_worker).to receive(:setup_metrics).and_call_original
            allow(TestConfig.config_instance).to receive(:get).and_call_original
            allow(TestConfig.config_instance).to receive(:get).with(:prometheus_port).and_return(9394)
            allow(VCAP::CloudController::StandaloneMetricsWebserver).to receive(:start_for_bosh_job)
          end

          it 'sets up a webserver' do
            cc_delayed_worker.start_working
            expect(cc_delayed_worker).to have_received(:setup_metrics)
            expect(VCAP::CloudController::StandaloneMetricsWebserver).to have_received(:start_for_bosh_job)
          end
        end
      end
    end
  end

  describe '#clear_locks!' do
    let(:cc_delayed_worker) { CloudController::DelayedWorker.new(options) }

    context 'when Delayed::Worker is used' do
      it 'clears the locks' do
        expect(environment).to receive(:setup_environment).with(nil)
        expect(Delayed::Worker).to receive(:new).with(anything).and_return(delayed_worker).once
        expect(delayed_worker).to receive(:name=).with(options[:name]).once
        expect(delayed_worker).to receive(:name).and_return(options[:name]).twice
        expect(Delayed::Job).to receive(:clear_locks!).with(options[:name]).once

        cc_delayed_worker.clear_locks!
      end
    end

    context 'when Delayed::ThreadedWorker is used' do
      it 'clears the locks for all threads' do
        expect(environment).to receive(:setup_environment).with(nil)
        expect(Delayed::Worker).to receive(:new).with(anything).and_return(threaded_worker).once
        expect(threaded_worker).to receive(:name=).with(options[:name]).once
        expect(threaded_worker).to receive(:name).and_return(options[:name]).twice
        expect(threaded_worker).to receive(:names_with_threads).and_return(["#{options[:name]} thread:1", "#{options[:name]} thread:2"]).once
        expect(Delayed::Job).to receive(:clear_locks!).with(options[:name]).once
        expect(Delayed::Job).to receive(:clear_locks!).with("#{options[:name]} thread:1").once
        expect(Delayed::Job).to receive(:clear_locks!).with("#{options[:name]} thread:2").once

        cc_delayed_worker.clear_locks!
      end
    end
  end
end
