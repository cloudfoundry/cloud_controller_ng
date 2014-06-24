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

    describe "Serialization" do
      it { should export_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description, :timestamp }
      it { should import_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description, :timestamp }
    end
  end
end
