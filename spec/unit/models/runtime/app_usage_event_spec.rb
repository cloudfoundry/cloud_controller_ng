require 'spec_helper'

module VCAP::CloudController
  describe AppUsageEvent, type: :model do
    describe 'Validations' do
      it { is_expected.to validate_db_presence :created_at }
      it { is_expected.to validate_db_presence :state }
      it { is_expected.to validate_db_presence :memory_in_mb_per_instance }
      it { is_expected.to validate_db_presence :instance_count }
      it { is_expected.to validate_db_presence :app_guid }
      it { is_expected.to validate_db_presence :app_name }
      it { is_expected.to validate_db_presence :space_guid }
      it { is_expected.to validate_db_presence :space_name }
      it { is_expected.to validate_db_presence :org_guid }
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :state, :memory_in_mb_per_instance, :instance_count, :app_guid, :app_name,
                                    :space_guid, :space_name, :org_guid, :buildpack_guid, :buildpack_name, :package_state,
                                    :parent_app_name, :parent_app_guid, :process_type
      }
      it { is_expected.to import_attributes }
    end
  end
end
