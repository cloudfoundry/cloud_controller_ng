require "spec_helper"

describe VCAP::CloudController::Runner do
  describe "#run!" do
    let(:runner) do
      runner = VCAP::CloudController::Runner.new(argv)
      runner.stub(:start_app)
      runner.stub(:start_cloud_controller)
      runner
    end

    def run!
      runner.run!
    end

    context "when the run migrations flag is passed in" do
      let(:argv) { ["-m"] }

      it "configures the stacks" do
        VCAP::CloudController::Models::Stack.should_receive(:configure)
        run!
      end

      it "does not populate the stacks" do
        VCAP::CloudController::Models::Stack.should_receive(:populate)
        run!
      end
    end

    context "when the run migrations flag is not passed in" do
      let(:argv) { [] }

      it "configures the stacks" do
        VCAP::CloudController::Models::Stack.should_receive(:configure)
        run!
      end

      it "populates the stacks" do
        VCAP::CloudController::Models::Stack.should_not_receive(:populate)
        run!
      end
    end
  end
end
