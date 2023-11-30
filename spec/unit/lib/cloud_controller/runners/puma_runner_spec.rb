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

    subject do
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
      PumaRunner.new(TestConfig.config_instance, app, logger, periodic_updater, request_logs)
    end

    before do
      allow(logger).to receive(:info)
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
        expect(puma_launcher.config.final_options[:min_threads]).to eq(0)
        expect(puma_launcher.config.final_options[:max_threads]).to eq(max_threads)
      end

      context 'when not specifying the number of workers and threads' do
        let(:num_workers) { nil }
        let(:max_threads) { nil }

        it 'configures 1 as default' do
          subject

          expect(puma_launcher.config.final_options[:workers]).to eq(1)
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
        puma_launcher.config.final_options[:before_fork].first.call
      end

      it 'logs incomplete requests on worker shutdown' do
        subject

        expect(request_logs).to receive(:log_incomplete_requests)
        puma_launcher.config.final_options[:before_worker_shutdown].first.call
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
      describe 'on_booted' do
        it 'sets up periodic metrics updater with EM' do
          expect(Thread).to receive(:new).and_yield
          expect(EM).to receive(:run).and_yield
          expect(periodic_updater).to receive(:setup_updates)

          puma_launcher.events.fire(:on_booted)
        end
      end

      describe 'on_stopped' do
        it 'stops EM and logs incomplete requests' do
          expect(EM).to receive(:stop)

          puma_launcher.events.fire(:on_stopped)
        end
      end
    end
  end
end
