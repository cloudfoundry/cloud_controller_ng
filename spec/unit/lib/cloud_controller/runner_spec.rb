require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Runner do
    let(:valid_config_file_path) { File.join(Paths::CONFIG, 'cloud_controller.yml') }
    let(:config_file) { File.new(valid_config_file_path) }
    let(:diagnostics) { instance_double(VCAP::CloudController::Diagnostics) }
    let(:periodic_updater) { instance_double(VCAP::CloudController::Metrics::PeriodicUpdater) }
    let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client, router_group_guid: '') }

    let(:argv) { [] }

    before do
      allow(Steno).to receive(:init)
      allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).and_return(routing_api_client)
      allow(EM).to receive(:run).and_yield
      allow(EM).to receive(:add_timer).and_yield
      allow(VCAP::CloudController::Metrics::PeriodicUpdater).to receive(:new).and_return(periodic_updater)
      allow(periodic_updater).to receive(:setup_updates)
      allow(VCAP::PidFile).to receive(:new) { double(:pidfile, unlink_at_exit: nil) }
      allow(VCAP::CloudController::Diagnostics).to receive(:new).and_return(diagnostics)
      allow(diagnostics).to receive(:collect)
    end

    subject do
      Runner.new(argv + ['-c', config_file.path]).tap do |r|
        allow(r).to receive(:start_thin_server)
      end
    end

    describe '#run!' do
      it 'creates a pidfile' do
        expect(VCAP::PidFile).to receive(:new).with('/tmp/cloud_controller.pid')
        subject.run!
      end

      it 'registers a log counter with the component' do
        log_counter = Steno::Sink::Counter.new
        expect(Steno::Sink::Counter).to receive(:new).once.and_return(log_counter)

        expect(Steno).to receive(:init) do |steno_config|
          expect(steno_config.sinks).to include log_counter
        end

        subject.run!
      end

      it 'sets up database' do
        expect(DB).to receive(:load_models)
        subject.run!
      end

      it 'configures components' do
        expect_any_instance_of(Config).to receive(:configure_components)
        subject.run!
      end

      it 'sets up loggregator emitter' do
        loggregator_emitter = double(:loggregator_emitter)
        expect(LoggregatorEmitter::Emitter).to receive(:new).and_return(loggregator_emitter)
        expect(VCAP::Loggregator).to receive(:emitter=).with(loggregator_emitter)
        subject.run!
      end

      it 'starts thin server on set up bind address' do
        allow(subject).to receive(:start_thin_server).and_call_original
        expect_any_instance_of(VCAP::HostSystem).to receive(:local_ip).and_return('some_local_ip')
        expect(Thin::Server).to receive(:new).with('some_local_ip', 8181, { signals: false }).and_return(double(:thin_server).as_null_object)
        subject.run!
      end

      it 'sets up varz updates' do
        expect(periodic_updater).to receive(:setup_updates)
        subject.run!
      end

      it 'logs an error if an exception is raised' do
        allow(subject).to receive(:start_cloud_controller).and_raise('we have a problem')
        expect(subject.logger).to receive(:error)
        expect { subject.run! }.to raise_exception('we have a problem')
      end

      it 'sets up logging before creating a logger' do
        steno_configurer = instance_double(StenoConfigurer)
        logger = Steno.logger('logger')
        allow(StenoConfigurer).to receive(:new).and_return(steno_configurer)

        logging_configuration_time = nil
        logger_creation_time = nil

        allow(steno_configurer).to receive(:configure) do
          logging_configuration_time ||= Time.now
        end

        allow(Steno).to receive(:logger) do |_|
          logger_creation_time ||= Time.now
          logger
        end

        subject.run!

        expect(logging_configuration_time).to be < logger_creation_time
      end

      it 'only sets up logging once' do
        steno_configurer = instance_double(StenoConfigurer)
        allow(StenoConfigurer).to receive(:new).and_return(steno_configurer)
        allow(steno_configurer).to receive(:configure).once

        subject.run!

        expect(steno_configurer).to have_received(:configure).once
      end

      it 'sets up the blobstore buckets' do
        droplet_blobstore = instance_double(CloudController::Blobstore::Client, :ensure_bucket_exists => nil)
        package_blobstore = instance_double(CloudController::Blobstore::Client, :ensure_bucket_exists => nil)
        resource_blobstore = instance_double(CloudController::Blobstore::Client, :ensure_bucket_exists => nil)
        buildpack_blobstore = instance_double(CloudController::Blobstore::Client, :ensure_bucket_exists => nil)

        expect(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).and_return(droplet_blobstore)
        expect(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
        expect(CloudController::DependencyLocator.instance).to receive(:global_app_bits_cache).and_return(resource_blobstore)
        expect(CloudController::DependencyLocator.instance).to receive(:buildpack_blobstore).and_return(buildpack_blobstore)

        subject.run!

        expect(droplet_blobstore).to have_received(:ensure_bucket_exists)
        expect(package_blobstore).to have_received(:ensure_bucket_exists)
        expect(resource_blobstore).to have_received(:ensure_bucket_exists)
        expect(buildpack_blobstore).to have_received(:ensure_bucket_exists)
      end
    end

    describe '#stop!' do
      it 'should stop thin and EM' do
        expect(subject).to receive(:stop_thin_server)
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

    describe '#initialize' do
      subject { Runner.new(argv_options) }
      let(:argv_options) { [] }

      before do
        allow_any_instance_of(Runner).to receive(:deprecation_warning)
      end

      describe 'argument parsing' do
        describe 'Configuration File' do
          ['-c', '--config'].each do |flag|
            describe flag do
              let(:argv_options) { [flag, config_file.path] }

              it "should set ENV['NEW_RELIC_ENV'] to production" do
                ENV.delete('NEW_RELIC_ENV')
                expect { subject }.to change { ENV['NEW_RELIC_ENV'] }.from(nil).to('production')
              end

              it 'should set the configuration file' do
                expect(subject.config_file).to eq(config_file.path)
              end
            end
          end
        end
      end
    end

    describe '#start_thin_server' do
      let(:app) { double(:app) }
      let(:thin_server) { OpenStruct.new(start!: nil) }

      subject(:start_thin_server) do
        runner = Runner.new(argv + ['-c', config_file.path])
        runner.send(:start_thin_server, app)
      end

      before do
        allow(Thin::Server).to receive(:new).and_return(thin_server)
        allow(thin_server).to receive(:start!)
      end

      it 'gets the timeout from the config' do
        start_thin_server

        expect(thin_server.timeout).to eq(600)
      end

      it "uses thin's experimental threaded mode intentionally" do
        start_thin_server

        expect(thin_server.threaded).to eq(true)
      end

      it 'starts the thin server' do
        start_thin_server

        expect(thin_server).to have_received(:start!)
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
