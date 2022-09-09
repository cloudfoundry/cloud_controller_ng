require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PumaRunner do
    let(:valid_config_file_path) { File.join(Paths::CONFIG, 'cloud_controller.yml') }
    let(:config_file) { File.new(valid_config_file_path) }
    let(:app) { double(:app) }
    let(:periodic_updater) { double(:periodic_updater) }
    let(:logger) { double(:logger) }
    let(:request_logs) { double(:request_logs) }

    before do
      allow(logger).to receive :info
      allow(EM).to receive(:run).and_yield
      allow_any_instance_of(Puma::Launcher).to receive(:run)
      allow(periodic_updater).to receive :setup_updates
      allow(VCAP::CloudController::Logs::RequestLogs).to receive(:new).and_return(request_logs)
    end

    subject do
      config = Config.load_from_file(config_file.path, context: :api, secrets_hash: {})
      config.set(:external_host, 'some_local_ip')
      PumaRunner.new(config, app, logger, periodic_updater)
    end

    describe 'start!' do
      it 'starts the puma server' do
        expect(Puma::Launcher).to receive(:new).with(an_instance_of(Puma::Configuration)).and_call_original
        expect_any_instance_of(Puma::Launcher).to receive(:run)
        subject.start!
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
