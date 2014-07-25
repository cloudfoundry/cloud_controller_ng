require "spec_helper"

describe MaxInstanceMemoryPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make(memory: 100, state: "STARTED") }
  let(:org) { app.organization }

  subject(:validator) { MaxInstanceMemoryPolicy.new(app) }

  context "when performing a scaling operation" do
    before do
      app.memory = 200
    end

    describe "quota instance memory limit" do
      it "gives error when app memory exceeds instance memory limit" do
        allow(org.quota_definition).to receive(:instance_memory_limit).and_return(150)
        expect(validator).to validate_with_error(app, :memory, :instance_memory_limit_exceeded)
      end

      it "does not give error when app memory equals instance memory limit" do
        allow(org.quota_definition).to receive(:instance_memory_limit).and_return(200)
        expect(validator).to validate_without_error(app)
      end

      it "does not give error when instance memory limit is -1" do
        allow(org.quota_definition).to receive(:instance_memory_limit).and_return(-1)
        expect(validator).to validate_without_error(app)
      end
    end
  end

  context "when not performing a scaling operation" do
    it "does not register error" do
      expect(validator).to validate_without_error(app)
    end
  end
end
