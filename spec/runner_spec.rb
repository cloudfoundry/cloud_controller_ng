require "spec_helper"

module VCAP::CloudController
  describe Runner do
    let(:valid_config_file_path) { File.join(fixture_path, "config/minimal_config.yml") }
    let(:config_file) { File.new(valid_config_file_path) }
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:registrar) { Cf::Registrar.new({}) }

    let(:argv) { [] }

    before do
      MessageBusConfigurer::Configurer.any_instance.stub(:go).and_return(message_bus)
      VCAP::Component.stub(:register)
      EM.stub(:run).and_yield
      EM.stub(:add_periodic_timer).and_yield

      registrar.stub(:message_bus => message_bus)
      registrar.stub(:register_with_router)
    end

    subject do
      Runner.new(argv + ["-c", config_file.path]).tap do |r|
        r.stub(:start_thin_server)
        r.stub(:create_pidfile)
        r.stub(:registrar => registrar)
      end
    end

    describe "#run!" do
      def self.it_configures_stacks
        it "configures the stacks" do
          Stack.should_receive(:configure)
          subject.run!
        end
      end

      def self.it_runs_dea_client
        it "starts running dea client (one time set up to start tracking deas)" do
          DeaClient.should_receive(:run)
          subject.run!
        end
      end

      def self.it_runs_app_stager
        it "starts running app stager (one time set up to start tracking stagers)" do
          AppObserver.should_receive(:run)
          subject.run!
        end
      end

      def self.it_handles_health_manager_requests
        it "starts handling health manager requests" do
          HealthManagerRespondent.any_instance.should_receive(:handle_requests)
          subject.run!
        end
      end

      def self.it_handles_hm9000_requests
        it "starts handling hm9000 requests" do
          hm9000respondent = double(:hm9000respondent)
          HM9000Respondent.should_receive(:new).with(DeaClient, message_bus, true).and_return(hm9000respondent)
          hm9000respondent.should_receive(:handle_requests)
          subject.run!
        end
      end

      def self.it_registers_a_log_counter
        it "registers a log counter with the component" do
          log_counter = Steno::Sink::Counter.new
          Steno::Sink::Counter.should_receive(:new).once.and_return(log_counter)

          Steno.should_receive(:init) do |steno_config|
            expect(steno_config.sinks).to include log_counter
          end

          VCAP::Component.should_receive(:register).with(hash_including(:log_counter => log_counter))
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

          it_configures_stacks
          it_runs_dea_client
          it_runs_app_stager
          it_handles_health_manager_requests
          it_handles_hm9000_requests

          describe "when the seed data has not yet been created" do
            before { subject.run! }

            it "creates stacks from the config file" do
              cider = Stack.find(:name => "cider")
              cider.description.should == "cider-description"
              cider.should be_valid
            end

            it "should load quota definitions" do
              QuotaDefinition.count.should == 2
              paid = QuotaDefinition[:name => "paid"]
              paid.non_basic_services_allowed.should == true
              paid.total_services.should == 500
              paid.memory_limit.should == 204800
            end

            it "creates the system domain organization" do
              expect(Organization.last.name).to eq("the-system-domain-org-name")
              expect(Organization.last.quota_definition.name).to eq("paid")
            end

            it "creates the system domain, owned by the system domain org" do
              domain = Domain.find(:name => "the-system-domain.com")
              expect(domain.owning_organization.name).to eq("the-system-domain-org-name")
              expect(domain.wildcard).to be_true
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

          context "when the 'paid' quota is missing from the config file" do
            let(:config_file) do
              config = YAML.load_file(valid_config_file_path)
              config["quota_definitions"].delete("paid")
              file = Tempfile.new("config")
              file.write(YAML.dump(config))
              file.rewind
              file
            end

            it "raises an exception" do
              expect {
                subject.run!
              }.to raise_error(ArgumentError, /Missing .*paid.* quota/)
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

            it "creates the system domain as a shared domain" do
              subject.run!
              domain = Domain.find(:name => "the-system-domain.com")
              expect(domain.owning_organization).to be_nil
              expect(domain.wildcard).to be_true
            end
          end
        end
      end

      context "when the insert seed flag is not passed in" do
        let(:argv) { [] }

        it_configures_stacks
        it_runs_dea_client
        it_runs_app_stager
        it_handles_health_manager_requests
        it_handles_hm9000_requests

        # This shouldn't be inside here but unless we run under this wrapper we
        # end up with state pollution and other tests fail. Should be refactored.
        it_registers_a_log_counter

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
  end
end
