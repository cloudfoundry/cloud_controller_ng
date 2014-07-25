require "spec_helper"

describe MaxMemoryPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make(memory: 100, state: "STARTED") }
  let(:organization) { app.organization }

  subject(:validator) { MaxMemoryPolicy.new(app) }

  context "when performing a scaling operation" do
    before do
      app.memory = 200
    end

    describe "quota memory limit" do
      it "registers error when quota is exceeded" do
        allow(organization).to receive(:memory_remaining).and_return(65)
        expect(validator).to validate_with_error(app, :memory, :quota_exceeded)
      end

      it "does not register error when quota is not exceeded" do
        allow(organization).to receive(:memory_remaining).and_return(1028)
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
