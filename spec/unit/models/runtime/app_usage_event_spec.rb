require "spec_helper"

module VCAP::CloudController
  describe AppUsageEvent, type: :model do
    describe "Validations" do
      it { should validate_db_presence :created_at }
      it { should validate_db_presence :state }
      it { should validate_db_presence :memory_in_mb_per_instance }
      it { should validate_db_presence :instance_count }
      it { should validate_db_presence :app_guid }
      it { should validate_db_presence :app_name }
      it { should validate_db_presence :space_guid }
      it { should validate_db_presence :space_name }
      it { should validate_db_presence :org_guid }
    end

    describe "Serialization" do
      it { should export_attributes :state, :memory_in_mb_per_instance, :instance_count, :app_guid, :app_name,
                                    :space_guid, :space_name, :org_guid, :buildpack_guid, :buildpack_name }
      it { should import_attributes }
    end
  end
end
