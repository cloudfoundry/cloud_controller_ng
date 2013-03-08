require "spec_helper"

describe VCAP::CloudController::Runner do
  describe "#run!" do
    before { VCAP::CloudController::MessageBus.stub(:new => MockMessageBus.new({})) }

    subject do
      config_path = File.expand_path("../fixtures/config/minimal_config.yml", __FILE__)
      VCAP::CloudController::Runner.new(argv + ["-c", config_path]).tap do |r|
        r.stub(:start_thin_server)
        r.stub(:create_pidfile)
      end
    end

    def self.it_configures_stacks
      it "configures the stacks" do
        VCAP::CloudController::Models::Stack.should_receive(:configure)
        subject.run!
      end
    end

    def self.it_runs_dea_client
      it "starts running dea client (one time set up to start tracking deas)" do
        VCAP::CloudController::DeaClient.should_receive(:run)
        subject.run!
      end
    end

    def self.it_runs_app_stager
      it "starts running app stager (one time set up to start tracking stagers)" do
        VCAP::CloudController::AppStager.should_receive(:run)
        subject.run!
      end
    end

    context "when the run migrations flag is passed in" do
      let(:argv) { ["-m"] }

      it_configures_stacks
      it_runs_dea_client
      it_runs_app_stager

      it "populate the stacks" do
        VCAP::CloudController::Models::Stack.should_receive(:populate)
        subject.run!
      end
    end

    context "when the run migrations flag is not passed in" do
      let(:argv) { [] }

      it_configures_stacks
      it_runs_dea_client
      it_runs_app_stager
    end
  end
end
