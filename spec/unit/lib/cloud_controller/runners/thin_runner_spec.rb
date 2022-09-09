require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ThinRunner do
    let(:valid_config_file_path) { File.join(Paths::CONFIG, 'cloud_controller.yml') }
    let(:config_file) { File.new(valid_config_file_path) }
    let(:app) { double(:app) }
    let(:logger) { double(:logger) }
    let(:argv) { [] }
    let(:periodic_updater) { double(:periodic_updater) }
    let(:diagnostics) { instance_double(VCAP::CloudController::Diagnostics) }
    let(:request_logs) { double(:request_logs) }

    before :each do
      allow(logger).to receive :info
      allow(logger).to receive :warn
      allow(periodic_updater).to receive :setup_updates
      allow(EM).to receive(:run).and_yield
      allow(EM).to receive(:add_timer).and_yield
      allow(VCAP::CloudController::Diagnostics).to receive(:new).and_return(diagnostics)
      allow(diagnostics).to receive(:collect)
      allow(VCAP::CloudController::Logs::RequestLogs).to receive(:new).and_return(request_logs)
    end

    subject do
      config = Config.load_from_file(config_file.path, context: :api, secrets_hash: {})
      config.set(:external_host, 'some_local_ip')
      ThinRunner.new(config, app, logger, periodic_updater)
    end

    it 'starts thin server on set up bind address' do
      thin_server = double(:thin_server).as_null_object
      expect(Thin::Server).to receive(:new).with('some_local_ip', 8181, { signals: false }).and_return(thin_server)
      subject.start!
      expect(subject.instance_variable_get(:@thin_server)).to eq(thin_server)
    end

    describe 'start!' do
      let(:app) { double(:app) }
      let(:thin_server) { OpenStruct.new(start!: nil) }

      before do
        allow(Thin::Server).to receive(:new).and_return(thin_server)
        allow(thin_server).to receive(:start!)
        subject.start!
      end

      it 'gets the timeout from the config' do
        expect(thin_server.timeout).to eq(600)
      end

      it "uses thin's experimental threaded mode intentionally" do
        expect(thin_server.threaded).to eq(true)
      end

      it 'starts the thin server' do
        expect(thin_server).to have_received(:start!)
      end

      it 'starts EventMachine' do
        expect(EM).to have_received(:run)
      end

      it 'sets up periodic updater updates' do
        expect(periodic_updater).to receive(:setup_updates)
        subject.start!
      end

      it 'logs an error if an exception is raised' do
        allow(thin_server).to receive(:start!).and_raise('we have a problem')
        expect(subject.logger).to receive(:error)
        expect { subject.start! }.to raise_exception('we have a problem')
      end
    end

    describe '#stop!' do
      let(:thin_server) { double(:thin_server) }

      before do
        subject.instance_variable_set(:@thin_server, thin_server)
      end

      it 'should stop thin and EM, logs incomplete requests' do
        expect(thin_server).to receive(:stop)
        expect(request_logs).to receive(:log_incomplete_requests)
        expect(EM).to receive(:stop)
        subject.stop!
      end
    end

    describe '#trap_signals' do
      it 'registers TERM, INT, QUIT and USR1 handlers' do
        expect(subject).to receive(:trap).with('TERM')
        expect(subject).to receive(:trap).with('INT')
        expect(subject).to receive(:trap).with('QUIT')
        expect(subject).to receive(:trap).with('USR1')
        subject.trap_signals
      end

      it 'calls #stop! when the handlers are triggered' do
        callbacks = []

        expect(subject).to receive(:trap).with('TERM') do |_, &blk|
          callbacks << blk
        end

        expect(subject).to receive(:trap).with('INT') do |_, &blk|
          callbacks << blk
        end

        expect(subject).to receive(:trap).with('QUIT') do |_, &blk|
          callbacks << blk
        end

        expect(subject).to receive(:trap).with('USR1') do |_, &blk|
          callbacks << blk
        end

        subject.trap_signals

        expect(subject).to receive(:stop!).exactly(3).times

        callbacks.each(&:call)
      end
    end

    describe '#collect_diagnostics' do
      callback = nil

      before do
        callback = nil
        expect(subject).to receive(:trap).with('TERM')
        expect(subject).to receive(:trap).with('INT')
        expect(subject).to receive(:trap).with('QUIT')
        expect(subject).to receive(:trap).with('USR1') do |_, &blk|
          callback = blk
        end
        subject.trap_signals
      end

      let(:config_file) do
        config = YAMLConfig.safe_load_file(valid_config_file_path)
        config['directories'] ||= { 'tmpdir' => 'tmpdir' }
        config['directories']['diagnostics'] = 'diagnostics/dir'
        file = Tempfile.new('config')
        file.write(YAML.dump(config))
        file.rewind
        file
      end

      it 'uses the configured directory' do
        expect(Dir).not_to receive(:mktmpdir)
        expect(subject).to receive(:collect_diagnostics).and_call_original
        expect(diagnostics).to receive(:collect).with('diagnostics/dir')

        callback.call
      end
    end
  end
end
