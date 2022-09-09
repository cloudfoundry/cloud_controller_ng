require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Runner do
    let(:valid_config_file_path) { File.join(Paths::CONFIG, 'cloud_controller.yml') }
    let(:config_file) { File.new(valid_config_file_path) }
    let(:periodic_updater) { instance_double(VCAP::CloudController::Metrics::PeriodicUpdater) }
    let(:routing_api_client) { instance_double(VCAP::CloudController::RoutingApi::Client, router_group_guid: '') }

    let(:argv) { [] }

    before do
      allow(Steno).to receive(:init)
      allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).and_return(routing_api_client)
      allow(EM).to receive(:run).and_yield
      allow(VCAP::CloudController::Metrics::PeriodicUpdater).to receive(:new).and_return(periodic_updater)
      allow(periodic_updater).to receive(:setup_updates)
      allow(VCAP::PidFile).to receive(:new) { double(:pidfile, unlink_at_exit: nil) }
      allow_any_instance_of(VCAP::CloudController::ThinRunner).to receive(:start!)
    end

    subject do
      Runner.new(argv + ['-c', config_file.path])
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
        expect(VCAP::AppLogEmitter).to receive(:emitter=).with(loggregator_emitter)
        subject.run!
      end

      context 'when fluent is configured' do
        let(:fluent_logger) { double(:fluent_logger) }
        let(:config_file) do
          config = YAMLConfig.safe_load_file(valid_config_file_path)
          config['fluent'] ||= {
            'host' => 'localhost',
            'port' => 24224,
          }
          file = Tempfile.new('config')
          file.write(YAML.dump(config))
          file.rewind
          file
        end

        it 'sets up fluent emitter' do
          expect(::Fluent::Logger::FluentLogger).to receive(:new).and_return(fluent_logger)
          expect(VCAP::AppLogEmitter).to receive(:fluent_emitter=).with(instance_of(VCAP::FluentEmitter))
          subject.run!
        end
      end

      it 'builds a rack app with request metrics and request logs handlers' do
        builder = instance_double(RackAppBuilder)
        allow(RackAppBuilder).to receive(:new).and_return(builder)
        request_logs = double(:request_logs)
        allow(VCAP::CloudController::Logs::RequestLogs).to receive(:new).and_return(request_logs)
        expect(builder).to receive(:build).with(anything, instance_of(VCAP::CloudController::Metrics::RequestMetrics),
                                                request_logs)
        subject.run!
      end

      it 'sets a local ip in the host system' do
        expect_any_instance_of(VCAP::HostSystem).to receive(:local_ip).and_return('some_local_ip')
        subject.run!
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
        allow(steno_configurer).to receive(:configure)

        subject.run!
        subject.run!

        expect(steno_configurer).to have_received(:configure).once
      end

      it 'sets up telemetry logging once' do
        allow(TelemetryLogger).to receive(:init)

        subject.run!
        subject.run!

        expect(TelemetryLogger).to have_received(:init).once
      end

      context 'telemetry logging disabled' do
        let(:config_file) do
          config = YAMLConfig.safe_load_file(valid_config_file_path)
          config.delete('telemetry_log_path')
          file = Tempfile.new('config')
          file.write(YAML.dump(config))
          file.rewind
          file
        end

        it 'sets up telemetry logging with nil logger' do
          allow(TelemetryLogger).to receive(:init)

          subject.run!

          expect(TelemetryLogger).to_not have_received(:init)
        end
      end

      it 'sets up the blobstore buckets' do
        droplet_blobstore = instance_double(CloudController::Blobstore::Client, ensure_bucket_exists: nil)
        package_blobstore = instance_double(CloudController::Blobstore::Client, ensure_bucket_exists: nil)
        resource_blobstore = instance_double(CloudController::Blobstore::Client, ensure_bucket_exists: nil)
        buildpack_blobstore = instance_double(CloudController::Blobstore::Client, ensure_bucket_exists: nil)

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

    describe '#initialize' do
      before do
        allow_any_instance_of(Runner).to receive(:deprecation_warning)
      end

      describe 'web server selection' do
        context 'when thin is specifed' do
          it 'chooses ThinRunner as the web server' do
            expect(subject.instance_variable_get(:@server)).to be_an_instance_of(ThinRunner)
          end
        end

        context 'when puma is specified' do
          before do
            TestConfig.override(webserver: 'puma')
            allow(Config).to receive(:load_from_file).and_return(TestConfig.config_instance)
          end

          it 'chooses puma as the web server' do
            expect(subject.instance_variable_get(:@server)).to be_an_instance_of(PumaRunner)
          end
        end
      end

      describe 'argument parsing' do
        subject { Runner.new(argv_options) }
        let(:argv_options) { [] }

        describe 'Configuration File' do
          ['-c', '--config'].each do |flag|
            describe flag do
              let(:argv_options) { [flag, config_file.path] }

              it "should set ENV['NEW_RELIC_ENV'] to production" do
                ENV.delete('NEW_RELIC_ENV')
                expect { subject }.to change { ENV['NEW_RELIC_ENV'] }.from(nil).to('production')
              end

              it 'should set the configuration file' do
                expect(subject.secrets_file).to eq(nil)
                expect(subject.config_file).to eq(config_file.path)
              end
            end
          end
        end

        describe 'Configuration File with Optional Secrets Files' do
          let(:secrets_file) do
            file = Tempfile.new('secrets_file.yml')
            file.write(YAML.dump({ 'cloud_controller_username_lookup_client_secret' => secret_value_file.path }))
            file.close
            file
          end
          let(:secret_value_file) do
            file = Tempfile.new('secret_value_file')
            file.write('some-password')
            file.close
            file
          end

          ['-s', '--secrets'].each do |flag|
            describe flag do
              let(:argv_options) { ['-c', config_file.path, flag, secrets_file.path] }

              it 'merges the values the secrets file references into the main config' do
                expect(subject.secrets_file).to eq(secrets_file.path)
                expect(subject.config.get(:cloud_controller_username_lookup_client_secret)).to eq('some-password')
              end
            end
          end
        end
      end
    end
  end
end
