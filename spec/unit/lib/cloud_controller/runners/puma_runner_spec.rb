require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PumaRunner do
    let(:port) { '8181' }
    let(:use_nginx) { true }
    let(:socket) { '/path/to/socket' }
    let(:num_workers) { 3 }
    let(:max_threads) { 4 }
    let(:app) { double(:app) }
    let(:logger) { double(:logger) }
    let(:periodic_updater) { double(:periodic_updater) }
    let(:request_logs) { double(:request_logs) }
    let(:puma_launcher) { subject.instance_variable_get(:@puma_launcher) }
    let(:dependency_locator) { instance_spy(CloudController::DependencyLocator) }
    let(:prometheus_updater) { spy(VCAP::CloudController::Metrics::PrometheusUpdater) }

    let(:test_config) do
      TestConfig.override(
        external_port: port,
        nginx: {
          use_nginx: use_nginx,
          instance_socket: socket
        },
        puma: {
          workers: num_workers,
          max_threads: max_threads
        }
      )
    end

    subject do
      PumaRunner.new(test_config, app, logger, periodic_updater, request_logs)
    end

    before do
      allow(logger).to receive(:info)
      allow(CloudController::DependencyLocator).to receive(:instance).and_return(dependency_locator)
      allow(dependency_locator).to receive(:prometheus_updater).and_return(prometheus_updater)
    end

    describe 'initialize' do
      it 'configures the puma launcher' do
        expect(Puma::Launcher).to receive(:new).with(
          an_instance_of(Puma::Configuration),
          log_writer: an_instance_of(Puma::LogWriter),
          events: an_instance_of(Puma::Events)
        )

        subject
      end

      it 'binds to the configured socket' do
        subject

        expect(puma_launcher.config.final_options[:binds].first).to eq("unix://#{socket}")
      end

      context 'when socket is not configured' do
        let(:socket) { '' }

        it 'binds to the nginx default port 3000' do
          subject
          expect(puma_launcher.config.final_options[:binds].first).to eq('tcp://0.0.0.0:3000')
        end
      end

      context 'when not using nginx' do
        let(:use_nginx) { false }

        it 'binds to the configured port' do
          subject

          expect(puma_launcher.config.final_options[:binds].first).to eq("tcp://0.0.0.0:#{port}")
        end
      end

      it 'configures workers and threads' do
        subject

        expect(puma_launcher.config.final_options[:workers]).to eq(num_workers)
        expect(puma_launcher.config.final_options[:min_threads]).to eq(max_threads)
        expect(puma_launcher.config.final_options[:max_threads]).to eq(max_threads)
      end

      context 'when not specifying the number of workers and threads' do
        let(:num_workers) { nil }
        let(:max_threads) { nil }

        it 'configures 1 as default' do
          subject

          expect(puma_launcher.config.final_options[:workers]).to eq(1)
          expect(puma_launcher.config.final_options[:min_threads]).to eq(1)
          expect(puma_launcher.config.final_options[:max_threads]).to eq(1)
        end
      end

      context 'when setting "automatic_worker_count" to false' do
        let(:test_config) do
          TestConfig.override(
            puma: {
              workers: 1,
              automatic_worker_count: false
            }
          )
        end

        before do
          allow(::Concurrent).to receive(:available_processor_count).and_return 8
        end

        it 'configures number of workers to the detected number of cores' do
          subject

          expect(puma_launcher.config.final_options[:workers]).to eq(1)
          expect(puma_launcher.config.final_options[:min_threads]).to eq(1)
          expect(puma_launcher.config.final_options[:max_threads]).to eq(1)
        end
      end

      context 'when setting "automatic_worker_count" to true' do
        let(:test_config) do
          TestConfig.override(
            puma: {
              workers: 1,
              automatic_worker_count: true
            }
          )
        end

        before do
          allow(::Concurrent).to receive(:available_processor_count).and_return 8
        end

        it 'configures number of workers the specified number of workers' do
          subject

          expect(puma_launcher.config.final_options[:workers]).to eq(8)
          expect(puma_launcher.config.final_options[:min_threads]).to eq(1)
          expect(puma_launcher.config.final_options[:max_threads]).to eq(1)
        end
      end

      it 'configures the app as middleware' do
        subject

        expect(app).to receive(:call)
        puma_launcher.config.app.call({})
      end

      it 'disconnects the database before forking workers' do
        subject

        expect(Sequel::Model.db).to receive(:disconnect)
        puma_launcher.config.final_options[:before_fork].first[:block].call
      end

      it 'logs incomplete requests before worker shutdown' do
        subject

        expect(request_logs).to receive(:log_incomplete_requests)
        puma_launcher.config.final_options[:before_worker_shutdown].first[:block].call
      end

      it 'initializes the cc_db_connection_pool_timeouts_total for the worker before worker boot' do
        subject

        expect(prometheus_updater).to receive(:update_gauge_metric).with(:cc_db_connection_pool_timeouts_total, 0, labels: { process_type: 'puma_worker' })
        puma_launcher.config.final_options[:before_worker_boot].first[:block].call
      end

      it 'sets environment variable `PROCESS_TYPE` to `puma_worker`' do
        subject

        puma_launcher.config.final_options[:before_worker_boot].first[:block].call
        expect(ENV.fetch('PROCESS_TYPE')).to eq('puma_worker')
      end
    end

    describe 'start!' do
      it 'starts the puma server' do
        expect(puma_launcher).to receive(:run)

        subject.start!
      end

      it 'logs an error if an exception is raised' do
        allow(puma_launcher).to receive(:run).and_raise('we have a problem')
        expect(logger).to receive(:error)

        expect { subject.start! }.to raise_exception('we have a problem')
      end
    end

    describe 'Events' do
      describe 'after_booted' do
        it 'sets up periodic metrics updater with EM and initializes cc_db_connection_pool_timeouts_total for the main process' do
          expect(periodic_updater).to receive(:setup_updates)
          expect(prometheus_updater).to receive(:update_gauge_metric).with(:cc_db_connection_pool_timeouts_total, 0, labels: { process_type: 'main' })

          puma_launcher.events.fire(:after_booted)
        end
      end

      describe 'after_stopped' do
        it 'stops the TimerTasks' do
          expect(periodic_updater).to receive(:stop_updates).and_return(true)
          expect(logger).to receive(:info).with(/Successfully stopped periodic updates/)

          puma_launcher.events.fire(:after_stopped)
        end

        it 'logs a warning if stopping the TimerTasks fails' do
          expect(periodic_updater).to receive(:stop_updates).and_return(false)
          expect(logger).to receive(:warn).with(/Failed to stop all periodic update tasks/)

          puma_launcher.events.fire(:after_stopped)
        end
      end
    end

    describe 'Logging' do
      it 'LogWriter.log uses Steno logger with :info level' do
        expect(logger).to receive(:log).with(:info, /log message/)

        puma_launcher.log_writer.log('log message')
      end

      it 'LogWriter.error uses Steno logger with :error level' do
        expect(logger).to receive(:log).with(:error, /ERROR: error message/)

        expect { puma_launcher.log_writer.error('error message') }.to raise_error(SystemExit)
      end
    end
  end
end
