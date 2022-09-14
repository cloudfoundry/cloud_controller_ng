require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PumaRunner do
    let(:valid_config_file_path) { File.join(Paths::CONFIG, 'cloud_controller.yml') }
    let(:config_file) { File.new(valid_config_file_path) }
    let(:unix_socket) { '/path/to/socket' }
    let(:app) { double(:app, call: nil) }
    let(:periodic_updater) { double(:periodic_updater) }
    let(:logger) { double(:logger) }
    let(:request_logs) { double(:request_logs) }

    before do
      allow(logger).to receive :info
      allow(EM).to receive(:run).and_yield
      allow_any_instance_of(Puma::Launcher).to receive(:run)
      allow(periodic_updater).to receive :setup_updates
    end

    subject do
      TestConfig.override(
        external_host: 'some_local_ip',
        nginx: {
          instance_socket: unix_socket
        }
      )
      PumaRunner.new(TestConfig.config_instance, app, logger, periodic_updater, request_logs)
    end

    describe 'start!' do
      it 'starts the puma server' do
        expect(Puma::Launcher).to receive(:new).with(an_instance_of(Puma::Configuration), events: anything).and_call_original
        expect_any_instance_of(Puma::Launcher).to receive(:run)
        subject.start!
      end

      it 'configures the app as middleware' do
        allow_any_instance_of(Puma::Launcher).to receive(:run)
        subject.start!
        puma_launcher = subject.instance_variable_get(:@puma_launcher)

        puma_launcher.config.app.call({})
        expect(app).to have_received(:call)
      end

      it 'binds to the configured unix socket' do
        allow_any_instance_of(Puma::Launcher).to receive(:run)
        subject.start!
        puma_launcher = subject.instance_variable_get(:@puma_launcher)

        expect(puma_launcher.config.options.user_options[:binds]).to include("unix://#{unix_socket}")
      end

      it 'configures workers and threads' do
        allow_any_instance_of(Puma::Launcher).to receive(:run)
        subject.start!
        puma_launcher = subject.instance_variable_get(:@puma_launcher)

        expect(puma_launcher.config.options.user_options[:min_threads]).to eq(0)
        expect(puma_launcher.config.options.user_options[:max_threads]).to eq(5)
        expect(puma_launcher.config.options.user_options[:workers]).to eq(3)
      end

      it 'sets up metrics updates in the after_worker_fork' do
        allow_any_instance_of(Puma::Launcher).to receive(:run)
        subject.start!
        puma_launcher = subject.instance_variable_get(:@puma_launcher)

        expect(periodic_updater).to receive(:setup_updates)
        allow(Thread).to receive(:new).and_yield
        allow(EM).to receive(:run).and_yield
        expect(EM).to receive(:run)
        puma_launcher.config.final_options[:after_worker_fork].first.call
      end

      it 'logs an error if an exception is raised' do
        allow_any_instance_of(Puma::Launcher).to receive(:run).and_raise('we have a problem')
        expect(logger).to receive(:error)
        expect { subject.start! }.to raise_exception('we have a problem')
      end
    end

    describe '#stop!' do
      it 'should stop puma and EM, logs incomplete requests' do
        expect(request_logs).to receive(:log_incomplete_requests)
        expect(EM).to receive(:stop)
        subject.stop!
      end

      it 'should get called when the launcher stops' do
        expect(subject).to receive(:stop!)
        subject.instance_variable_get(:@puma_launcher).events.fire(:on_stopped)
      end
    end
  end
end
