require "spec_helper"

module VCAP::CloudController
  describe ServiceUsageEvent, type: :model do
    describe "Validations" do
      it { should validate_db_presence :created_at }
      it { should validate_db_presence :state }
      it { should validate_db_presence :org_guid }
      it { should validate_db_presence :space_guid }
      it { should validate_db_presence :space_name }
      it { should validate_db_presence :service_instance_guid }
      it { should validate_db_presence :service_instance_name }
      it { should validate_db_presence :service_instance_type }
    end

    describe "Serialization" do
      it { should export_attributes :state, :org_guid, :space_guid, :space_name, :service_instance_guid, :service_instance_name,
                                    :service_instance_type, :service_plan_guid, :service_plan_name, :service_guid, :service_label }
      it { should import_attributes }
    end
  end
end
