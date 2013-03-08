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

    context "when the run migrations flag is passed in" do
      let(:argv) { ["-m"] }

      it "configures the stacks" do
        VCAP::CloudController::Models::Stack.should_receive(:configure)
        subject.run!
      end

      it "populate the stacks" do
        VCAP::CloudController::Models::Stack.should_receive(:populate)
        subject.run!
      end
    end

    context "when the run migrations flag is not passed in" do
      let(:argv) { [] }

      it "configures the stacks" do
        VCAP::CloudController::Models::Stack.should_receive(:configure)
        subject.run!
      end
    end
  end
end
