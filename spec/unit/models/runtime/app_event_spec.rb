require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppEvent, type: :model do
    it_behaves_like "a CloudController model", {
    }
    describe "Validations" do
      it { should validate_presence :app }
      it { should validate_presence :instance_guid }
      it { should validate_presence :instance_index }
      it { should validate_presence :exit_status }
      it { should validate_presence :timestamp }
    end
  end
end
