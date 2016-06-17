require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceUsageEvent, type: :model do
    describe 'Validations' do
      it { is_expected.to validate_db_presence :created_at }
      it { is_expected.to validate_db_presence :state }
      it { is_expected.to validate_db_presence :org_guid }
      it { is_expected.to validate_db_presence :space_guid }
      it { is_expected.to validate_db_presence :space_name }
      it { is_expected.to validate_db_presence :service_instance_guid }
      it { is_expected.to validate_db_presence :service_instance_name }
      it { is_expected.to validate_db_presence :service_instance_type }
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :state, :org_guid, :space_guid, :space_name, :service_instance_guid, :service_instance_name,
                                    :service_instance_type, :service_plan_guid, :service_plan_name, :service_guid, :service_label
      }
      it { is_expected.to import_attributes }
    end
  end
end
