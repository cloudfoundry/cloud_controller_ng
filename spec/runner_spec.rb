require "spec_helper"

module VCAP::CloudController
  describe Runner do
    let(:valid_config_file_path) { File.join(fixture_path, "config/minimal_config.yml") }
    let(:config_file) { File.new(valid_config_file_path) }
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:registrar) { Cf::Registrar.new({}) }

    let(:argv) { [] }

    before do
      MessageBus::Configurer.any_instance.stub(:go).and_return(message_bus)
      VCAP::Component.stub(:register)
      EM.stub(:run).and_yield
      VCAP::CloudController::Varz.stub(:setup_updates)
      VCAP::PidFile.stub(:new) { double(:pidfile, unlink_at_exit: nil) }
      registrar.stub(:message_bus => message_bus)
      registrar.stub(:register_with_router)
    end

    subject do
      Runner.new(argv + ["-c", config_file.path]).tap do |r|
        r.stub(:start_thin_server)
        r.stub(:router_registrar => registrar)
      end
    end

    describe "#run!" do
      shared_examples "running Cloud Controller" do
        it "creates a pidfile" do
          expect(VCAP::PidFile).to receive(:new).with("/tmp/cloud_controller.pid")
          subject.run!
        end

        it "registers a log counter with the component" do
          log_counter = Steno::Sink::Counter.new
          expect(Steno::Sink::Counter).to receive(:new).once.and_return(log_counter)

          expect(Steno).to receive(:init) do |steno_config|
            expect(steno_config.sinks).to include log_counter
          end

          expect(VCAP::Component).to receive(:register).with(hash_including(:log_counter => log_counter))
          subject.run!
        end

        it "sets up database" do
          expect(DB).to receive(:load_models)
          subject.run!
        end

        it "configures components" do
          expect(Config).to receive(:configure_components)
          subject.run!
        end

        it "sets up loggregator emitter" do
          loggregator_emitter = double(:loggregator_emitter)
          expect(LoggregatorEmitter::Emitter).to receive(:new).and_return(loggregator_emitter)
          expect(Loggregator).to receive(:emitter=).with(loggregator_emitter)
          subject.run!
        end

        it "configures components depending on message bus" do
          expect(Config).to receive(:configure_components_depending_on_message_bus).with(message_bus)
          subject.run!
        end

        it "starts thin server on set up bind address" do
          subject.unstub(:start_thin_server)
          expect(VCAP).to receive(:local_ip).and_return("some_local_ip")
          expect(Thin::Server).to receive(:new).with("some_local_ip", 8181).and_return(double(:thin_server).as_null_object)
          subject.run!
        end

        it "starts running dea client (one time set up to start tracking deas)" do
          expect(DeaClient).to receive(:run)
          subject.run!
        end

        it "starts app observer" do
          expect(AppObserver).to receive(:run)
          subject.run!
        end

        it "registers subscription for Bulk API" do
          expect(LegacyBulk).to receive(:register_subscription)
          subject.run!
        end

        it "starts handling hm9000 requests" do
          hm9000respondent = double(:hm9000respondent)
          expect(HM9000Respondent).to receive(:new).with(DeaClient, message_bus, true).and_return(hm9000respondent)
          expect(hm9000respondent).to receive(:handle_requests)
          subject.run!
        end

        it "starts dea respondent" do
          dea_respondent = double(:dea_respondent)
          expect(DeaRespondent).to receive(:new).with(message_bus).and_return(dea_respondent)
          expect(dea_respondent).to receive(:start)
          subject.run!
        end

        it "registers with router" do
          expect(registrar).to receive(:register_with_router)
          subject.run!
        end

        it "sets up varz updates" do
          expect(VCAP::CloudController::Varz).to receive(:setup_updates)
          subject.run!
        end
      end

      describe "insert seed flag" do
        context "when the insert seed flag is passed in" do
          let(:argv) { ["-s"] }
          before do
            QuotaDefinition.dataset.destroy
            Stack.stub(:configure)
          end

          it_behaves_like "running Cloud Controller"

          describe "when the seed data has not yet been created" do
            before { subject.run! }

            it "creates stacks from the config file" do
              cider = Stack.find(:name => "cider")
              cider.description.should == "cider-description"
              cider.should be_valid
            end

            it "should load quota definitions" do
              QuotaDefinition.count.should == 2
              default = QuotaDefinition[:name => "default"]
              default.non_basic_services_allowed.should == true
              default.total_services.should == 100
              default.memory_limit.should == 10240
            end

            it "creates the system domain organization" do
              expect(Organization.last.name).to eq("the-system-domain-org-name")
              expect(Organization.last.quota_definition.name).to eq("default")
            end

            it "creates the system domain, owned by the system domain org" do
              domain = Domain.find(:name => "the-system-domain.com")
              expect(domain.owning_organization.name).to eq("the-system-domain-org-name")
            end

            it "creates the application serving domains" do
              ["customer-app-domain1.com", "customer-app-domain2.com"].each do |domain|
                expect(Domain.find(:name => domain)).not_to be_nil
                expect(Domain.find(:name => domain).owning_organization).to be_nil
              end
            end
          end

          it "does not try to create the system domain twice" do
            subject.run!
            expect { subject.run! }.not_to change(Domain, :count)
          end

          context "when the 'default' quota is missing from the config file" do
            let(:config_file) do
              config = YAML.load_file(valid_config_file_path)
              config["quota_definitions"].delete("default")
              file = Tempfile.new("config")
              file.write(YAML.dump(config))
              file.rewind
              file
            end

            it "raises an exception" do
              expect {
                subject.run!
              }.to raise_error(ArgumentError, /Missing .*default.* quota/)
            end
          end

          context "when the app domains include the system domain" do
            let(:config_file) do
              config = YAML.load_file(valid_config_file_path)
              config["app_domains"].push("the-system-domain.com")
              file = Tempfile.new("config")
              file.write(YAML.dump(config))
              file.rewind
              file
            end

            it "creates the system domain as a private domain" do
              subject.run!
              domain = Domain.find(:name => "the-system-domain.com")
              expect(domain.owning_organization).to be_nil
            end
          end
        end
      end

      context "when the insert seed flag is not passed in" do
        let(:argv) { [] }

        it_behaves_like "running Cloud Controller"

        it "registers with the router" do
          registrar.should_receive(:register_with_router)
          subject.run!
        end
      end
    end

    describe "#stop!" do
      it "should stop thin and EM after unregistering routes" do
        registrar.should_receive(:shutdown).and_yield
        subject.should_receive(:stop_thin_server)
        EM.should_receive(:stop)
        subject.stop!
      end
    end

    describe "#trap_signals" do
      it "registers TERM, INT, and QUIT handlers" do
        subject.should_receive(:trap).with("TERM")
        subject.should_receive(:trap).with("INT")
        subject.should_receive(:trap).with("QUIT")
        subject.trap_signals
      end

      it "calls #stop! when the handlers are triggered" do
        callbacks = []

        subject.should_receive(:trap).with("TERM") do |_, &blk|
          callbacks << blk
        end

        subject.should_receive(:trap).with("INT") do |_, &blk|
          callbacks << blk
        end

        subject.should_receive(:trap).with("QUIT") do |_, &blk|
          callbacks << blk
        end

        subject.trap_signals

        subject.should_receive(:stop!).exactly(3).times
        callbacks.each(&:call)
      end
    end

    describe "#initialize" do
      let (:argv_options) { [] }

      before do
        Runner.any_instance.stub(:parse_config)
        Runner.any_instance.stub(:deprecation_warning)
      end

      subject { Runner.new(argv_options) }

      it "should set ENV['RACK_ENV'] to production" do
        ENV.delete('RACK_ENV')
        expect { subject }.to change { ENV['RACK_ENV'] }.from(nil).to('production')
      end

      it "should set the configuration file" do
        expect(subject.config_file).to eq(File.expand_path('config/cloud_controller.yml'))
      end

      describe 'argument parsing' do
        describe "Configuration File" do
          ["-c", "--config"].each do |flag|
            describe flag do
              let (:argv_options) { [flag, "config/minimal_config.yml"] }

              it "should set the configuration file" do
                expect(subject.config_file).to eq("config/minimal_config.yml")
              end
            end
          end
        end

        describe "Insert seed data" do
          ["-s", "--insert-seed"].each do |flag|
            let (:argv_options) { [flag] }

            it "should set insert_seed_data to true" do
              expect(subject.insert_seed_data).to be_true
            end
          end

          ["-m", "--run-migrations"].each do |flag|
            let (:argv_options) { [flag] }

            it "should set insert_seed_data to true" do
              Runner.any_instance.should_receive(:deprecation_warning).with("Deprecated: Use -s or --insert-seed flag")
              expect(subject.insert_seed_data).to be_true
            end
          end
        end
      end
    end

    describe "#start_thin_server" do
      let(:app) { double(:app) }
      let(:config) { double(:config) }
      let(:thin_server) { OpenStruct.new }

      subject(:start_thin_server) do
        runner = Runner.new(argv + ["-c", config_file.path])
        runner.send(:start_thin_server, app, config)
      end

      before do
        allow(Thin::Server).to receive(:new).and_return(thin_server)
        allow(thin_server).to receive(:start!)
      end

      it "has the same timeout as the rack application" do
        start_thin_server

        expect(thin_server.timeout).to eq(5.minutes)
      end

      it "uses thin's experimental threaded mode intentionally" do
        start_thin_server

        expect(thin_server.threaded).to eq(true)
      end

      it "starts the thin server" do
        start_thin_server

        expect(thin_server).to have_received(:start!)
      end
    end
  end
end
