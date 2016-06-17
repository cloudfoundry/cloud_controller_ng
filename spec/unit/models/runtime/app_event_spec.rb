require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::AppEvent, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :app }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :app }
      it { is_expected.to validate_presence :instance_guid }
      it { is_expected.to validate_presence :instance_index }
      it { is_expected.to validate_presence :exit_status }
      it { is_expected.to validate_presence :timestamp }
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description, :timestamp }
      it { is_expected.to import_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description, :timestamp }
    end
  end
end
