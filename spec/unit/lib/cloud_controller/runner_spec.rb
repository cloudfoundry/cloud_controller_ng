require 'spec_helper'

module VCAP::CloudController
  describe Runner do
    let(:valid_config_file_path) { File.join(Paths::FIXTURES, 'config/minimal_config.yml') }
    let(:config_file) { File.new(valid_config_file_path) }
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:registrar) { Cf::Registrar.new({}) }

    let(:argv) { [] }

    before do
      allow(Steno).to receive(:init)
      allow_any_instance_of(MessageBus::Configurer).to receive(:go).and_return(message_bus)
      allow(VCAP::Component).to receive(:register)
      allow(EM).to receive(:run).and_yield
      allow(EM).to receive(:add_timer).and_yield
      allow(VCAP::CloudController::Varz).to receive(:setup_updates)
      allow(VCAP::PidFile).to receive(:new) { double(:pidfile, unlink_at_exit: nil) }
      allow(registrar).to receive_messages(message_bus: message_bus)
      allow(registrar).to receive(:register_with_router)
    end

    subject do
      Runner.new(argv + ['-c', config_file.path]).tap do |r|
        allow(r).to receive(:start_thin_server)
        allow(r).to receive_messages(router_registrar: registrar)
      end
    end

    describe '#run!' do
      shared_examples 'running Cloud Controller' do
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

          expect(VCAP::Component).to receive(:register).with(hash_including(log_counter: log_counter))
          subject.run!
        end

        it 'sets up database' do
          expect(DB).to receive(:load_models)
          subject.run!
        end

        it 'configures components' do
          expect(Config).to receive(:configure_components)
          subject.run!
        end

        it 'sets up loggregator emitter' do
          loggregator_emitter = double(:loggregator_emitter)
          expect(LoggregatorEmitter::Emitter).to receive(:new).and_return(loggregator_emitter)
          expect(Loggregator).to receive(:emitter=).with(loggregator_emitter)
          subject.run!
        end

        it 'configures components depending on message bus' do
          expect(Config).to receive(:configure_components_depending_on_message_bus).with(message_bus)
          subject.run!
        end

        it 'starts thin server on set up bind address' do
          allow(subject).to receive(:start_thin_server).and_call_original
          expect(VCAP).to receive(:local_ip).and_return('some_local_ip')
          expect(Thin::Server).to receive(:new).with('some_local_ip', 8181, { signals: false }).and_return(double(:thin_server).as_null_object)
          subject.run!
        end

        it 'starts running dea client (one time set up to start tracking deas)' do
          expect(Dea::Client).to receive(:run)
          subject.run!
        end

        it 'registers subscription for Bulk API' do
          expect(LegacyBulk).to receive(:register_subscription)
          subject.run!
        end

        it 'starts handling hm9000 requests' do
          hm9000respondent = double(:hm9000respondent)
          expect(Dea::HM9000::Respondent).to receive(:new).with(Dea::Client, message_bus).and_return(hm9000respondent)
          expect(hm9000respondent).to receive(:handle_requests)
          subject.run!
        end

        it 'starts dea respondent' do
          dea_respondent = double(:dea_respondent)
          expect(Dea::Respondent).to receive(:new).with(message_bus).and_return(dea_respondent)
          expect(dea_respondent).to receive(:start)
          subject.run!
        end

        it 'registers with router' do
          expect(registrar).to receive(:register_with_router)
          subject.run!
        end

        it 'sets up varz updates' do
          expect(VCAP::CloudController::Varz).to receive(:setup_updates)
          subject.run!
        end

        it 'logs an error if an exception is raised' do
          allow(subject).to receive(:start_cloud_controller).and_raise('we have a problem')
          expect(subject.logger).to receive(:error)
          expect { subject.run! }.to raise_exception
        end
      end

      describe 'insert seed flag' do
        context 'when the insert seed flag is passed in' do
          let(:argv) { ['-s'] }
          before do
            Organization.dataset.destroy
            QuotaDefinition.dataset.destroy
            SecurityGroup.dataset.destroy
            allow(Stack).to receive(:configure)
          end

          it_behaves_like 'running Cloud Controller'

          describe 'when the seed data has not yet been created' do
            before { subject.run! }

            it 'creates stacks from the config file' do
              cider = Stack.find(name: 'cider')
              expect(cider.description).to eq('cider-description')
              expect(cider).to be_valid
            end

            it 'should load quota definitions' do
              expect(QuotaDefinition.count).to eq(2)
              default = QuotaDefinition[name: 'default']
              expect(default.non_basic_services_allowed).to eq(true)
              expect(default.total_services).to eq(100)
              expect(default.memory_limit).to eq(10240)
            end

            it 'creates the system domain organization' do
              expect(Organization.last.name).to eq('the-system-domain-org-name')
              expect(Organization.last.quota_definition.name).to eq('default')
            end

            it 'creates the system domain, owned by the system domain org' do
              domain = Domain.find(name: 'the-system-domain.com')
              expect(domain.owning_organization.name).to eq('the-system-domain-org-name')
            end

            it 'creates the application serving domains' do
              ['customer-app-domain1.com', 'customer-app-domain2.com'].each do |domain|
                expect(Domain.find(name: domain)).not_to be_nil
                expect(Domain.find(name: domain).owning_organization).to be_nil
              end
            end

            it 'creates the security group defaults' do
              expect(SecurityGroup.count).to eq(1)
            end
          end

          it 'does not try to create the system domain twice' do
            subject.run!
            expect { subject.run! }.not_to change(Domain, :count)
          end

          context "when the 'default' quota is missing from the config file" do
            let(:config_file) do
              config = YAML.load_file(valid_config_file_path)
              config['quota_definitions'].delete('default')
              file = Tempfile.new('config')
              file.write(YAML.dump(config))
              file.rewind
              file
            end

            it 'raises an exception' do
              expect {
                subject.run!
              }.to raise_error(ArgumentError, /Missing .*default.* quota/)
            end
          end

          context 'when the app domains include the system domain' do
            let(:config_file) do
              config = YAML.load_file(valid_config_file_path)
              config['app_domains'].push('the-system-domain.com')
              file = Tempfile.new('config')
              file.write(YAML.dump(config))
              file.rewind
              file
            end

            it 'creates the system domain as a private domain' do
              subject.run!
              domain = Domain.find(name: 'the-system-domain.com')
              expect(domain.owning_organization).to be_nil
            end
          end
        end
      end

      context 'when the insert seed flag is not passed in' do
        let(:argv) { [] }

        it_behaves_like 'running Cloud Controller'

        it 'registers with the router' do
          expect(registrar).to receive(:register_with_router)
          subject.run!
        end
      end
    end

    describe '#stop!' do
      it 'should stop thin and EM after unregistering routes' do
        expect(registrar).to receive(:shutdown).and_yield
        expect(subject).to receive(:stop_thin_server)
        expect(EM).to receive(:stop)
        subject.stop!
      end
    end

    describe '#trap_signals' do
      it 'registers TERM, INT, QUIT, USR1, and USR2 handlers' do
        expect(subject).to receive(:trap).with('TERM')
        expect(subject).to receive(:trap).with('INT')
        expect(subject).to receive(:trap).with('QUIT')
        expect(subject).to receive(:trap).with('USR1')
        expect(subject).to receive(:trap).with('USR2')
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

        expect(subject).to receive(:trap).with('USR2') do |_, &blk|
          callbacks << blk
        end

        subject.trap_signals

        expect(subject).to receive(:stop!).exactly(3).times

        registrar = double(:registrar)
        expect(subject).to receive(:router_registrar).and_return(registrar)
        expect(registrar).to receive(:shutdown)

        callbacks.each(&:call)
      end
    end

    describe '#initialize' do
      let(:argv_options) { [] }

      before do
        allow_any_instance_of(Runner).to receive(:deprecation_warning)
      end

      subject { Runner.new(argv_options) }

      it "should set ENV['RACK_ENV'] to production" do
        ENV.delete('RACK_ENV')
        expect { subject }.to change { ENV['RACK_ENV'] }.from(nil).to('production')
      end

      it 'should set the configuration file' do
        expect(subject.config_file).to eq(File.expand_path('config/cloud_controller.yml'))
      end

      describe 'argument parsing' do
        describe 'Configuration File' do
          ['-c', '--config'].each do |flag|
            describe flag do
              let(:argv_options) { [flag, config_file.path] }

              it 'should set the configuration file' do
                expect(subject.config_file).to eq(config_file.path)
              end
            end
          end
        end

        describe 'Insert seed data' do
          ['-s', '--insert-seed'].each do |flag|
            let(:argv_options) { [flag] }

            it 'should set insert_seed_data to true' do
              expect(subject.insert_seed_data).to be true
            end
          end

          ['-m', '--run-migrations'].each do |flag|
            let(:argv_options) { [flag] }

            it 'should set insert_seed_data to true' do
              expect_any_instance_of(Runner).to receive(:deprecation_warning).with('Deprecated: Use -s or --insert-seed flag')
              expect(subject.insert_seed_data).to be true
            end
          end
        end
      end
    end

    describe '#start_thin_server' do
      let(:app) { double(:app) }
      let(:thin_server) { OpenStruct.new }
      let(:valid_config_file_path) { File.join(Paths::FIXTURES, 'config/default_overriding_config.yml') }

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

    describe 'internationalization' do
      let(:config_file) do
        config = YAML.load_file(valid_config_file_path)
        config['default_locale'] = 'never_Neverland'
        file = Tempfile.new('config')
        file.write(YAML.dump(config))
        file.rewind
        file
      end

      it 'initializes the i18n framework with the correct locale' do
        expect(Errors::ApiError).to receive(:setup_i18n).with(anything, 'never_Neverland')
        subject.run!
      end
    end

    describe '#collect_diagnostics' do
      callback = nil

      before do
        callback = nil
        expect(subject).to receive(:trap).with('TERM')
        expect(subject).to receive(:trap).with('INT')
        expect(subject).to receive(:trap).with('QUIT')
        expect(subject).to receive(:trap).with('USR2')
        expect(subject).to receive(:trap).with('USR1') do |_, &blk|
          callback = blk
        end
        subject.trap_signals
      end

      context 'when the diagnostics directory is not configured' do
        it 'uses a temporary directory' do
          expect(Dir).to receive(:mktmpdir).and_return('some/tmp/dir')
          expect(subject).to receive(:collect_diagnostics).and_call_original
          expect(::VCAP::CloudController::Diagnostics).to receive(:collect).with('some/tmp/dir')

          callback.call
        end

        it 'memoizes the temporary directory' do
          expect(Dir).to receive(:mktmpdir).and_return('some/tmp/dir')
          expect(subject).to receive(:collect_diagnostics).twice.and_call_original
          expect(::VCAP::CloudController::Diagnostics).to receive(:collect).with('some/tmp/dir').twice

          callback.call
          callback.call
        end
      end

      context 'when the diagnostics directory is not configured' do
        let(:config_file) do
          config = YAML.load_file(valid_config_file_path)
          config[:directories] ||= {}
          config[:directories][:diagnostics] = 'diagnostics/dir'
          file = Tempfile.new('config')
          file.write(YAML.dump(config))
          file.rewind
          file
        end

        it 'uses the configured directory' do
          expect(Dir).not_to receive(:mktmpdir)
          expect(subject).to receive(:collect_diagnostics).and_call_original
          expect(::VCAP::CloudController::Diagnostics).to receive(:collect).with('diagnostics/dir')

          callback.call
        end
      end
    end
  end
end
