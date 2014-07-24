require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::SpaceQuotaDefinition, type: :model do
    let(:space_quota_definition) { SpaceQuotaDefinition.make }

    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it { is_expected.to have_associated :organization }
    end

    describe "Validations" do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :non_basic_services_allowed }
      it { is_expected.to validate_presence :total_services }
      it { is_expected.to validate_presence :total_routes }
      it { is_expected.to validate_presence :memory_limit }
      it { is_expected.to validate_presence :organization }
      it { is_expected.to validate_uniqueness [:organization_id, :name] }
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit }
      it { is_expected.to import_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit }
    end
  end
end
