require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe Runner do
    let(:valid_config_file_path) { File.expand_path("../fixtures/config/minimal_config.yml", __FILE__) }
    let(:config_file_path) { valid_config_file_path }
    let(:message_bus) { CfMessageBus::MockMessageBus.new }

    let(:argv) { [] }

    before do
      MessageBusConfigurer::Configurer.any_instance.stub(:go).and_return(message_bus)
      VCAP::Component.stub(:register)
      EM.stub(:run).and_yield
    end

    subject do
      Runner.new(argv + ["-c", config_file_path]).tap do |r|
        r.stub(:start_thin_server)
        r.stub(:create_pidfile)
      end
    end

    describe "#run!" do
      def self.it_configures_stacks
        it "configures the stacks" do
          Models::Stack.should_receive(:configure)
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
          AppStager.should_receive(:run)
          subject.run!
        end
      end

      context "when the run migrations flag is passed in" do
        let(:argv) { ["-m"] }

        before do
          reset_database
          Models::QuotaDefinition.dataset.destroy
          Models::Stack.stub(:configure)
        end

        it_configures_stacks
        it_runs_dea_client
        it_runs_app_stager

        describe "when the seed data has not yet been created" do
          before { subject.run! }

          it "creates stacks from the config file" do
            cider = Models::Stack.find(:name => "cider")
            cider.description.should == "cider-description"
            cider.should be_valid
          end

          it "should load quota definitions" do
            Models::QuotaDefinition.count.should == 2
            paid = Models::QuotaDefinition[:name => "paid"]
            paid.non_basic_services_allowed.should == true
            paid.total_services.should == 500
            paid.memory_limit.should == 204800
          end

          it "creates the system domain organization" do
            expect(Models::Organization.last.name).to eq("the-system-domain-org-name")
            expect(Models::Organization.last.quota_definition.name).to eq("paid")
          end

          it "creates the system domain, owned by the system domain org" do
            domain = Models::Domain.find(:name => "the-system-domain.com")
            expect(domain.owning_organization.name).to eq("the-system-domain-org-name")
            expect(domain.wildcard).to be_true
          end

          it "creates the application serving domains" do
            ["customer-app-domain1.com", "customer-app-domain2.com"].each do |domain|
              expect(Models::Domain.find(:name => domain)).not_to be_nil
              expect(Models::Domain.find(:name => domain).owning_organization).to be_nil
            end
          end
        end

        context "when the seed data has already been created" do
          it "Does not try to create the system domain" do
            subject.run!
            expect { subject.run! }.not_to change(Models::Domain, :count)
          end
        end

        context "when the 'paid' quote is mising from the config file" do
          let(:config_file_path) do
            config = YAML.load_file(valid_config_file_path)
            config["quota_definitions"].delete("paid")
            file = Tempfile.new("config")
            file.write(YAML.dump(config))
            file.rewind
            file.path
          end

          it "raises an exception" do
            expect {
              subject.run!
            }.to raise_error(ArgumentError, /Missing .*paid.* quota/)
          end
        end

        context "when the app domains include the system domain" do
          let(:config_file_path) do
            config = YAML.load_file(valid_config_file_path)
            config["app_domains"].push("the-system-domain.com")
            file = Tempfile.new("config")
            file.write(YAML.dump(config))
            file.rewind
            file.path
          end

          it "creates the system domain as a shared domain" do
            subject.run!
            domain = Models::Domain.find(:name => "the-system-domain.com")
            expect(domain.owning_organization).to be_nil
            expect(domain.wildcard).to be_true
          end
        end
      end

      context "when the run migrations flag is not passed in" do
        let(:argv) { [] }

        it_configures_stacks
        it_runs_dea_client
        it_runs_app_stager
      end
    end

    describe "#stop!" do
      it 'should stop thin and EM after unregistering routes' do
        RouterClient.should_receive(:unregister).and_yield
        subject.should_receive(:stop_thin_server)
        EM.should_receive(:stop)
        subject.stop!(message_bus)
      end
    end

    describe "#trap_signals" do
      context "when TERM is sent" do

      end

      it "registers TERM, INT, and QUIT handlers" do
        subject.should_receive(:trap).with("TERM")
        subject.should_receive(:trap).with("INT")
        subject.should_receive(:trap).with("QUIT")
        subject.trap_signals(message_bus)
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

        subject.trap_signals(message_bus)

        subject.should_receive(:stop!).exactly(3).times
        callbacks.each(&:call)
      end
    end
  end
end