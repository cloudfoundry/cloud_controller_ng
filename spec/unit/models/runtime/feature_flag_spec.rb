require "spec_helper"

module VCAP::CloudController
  describe FeatureFlag, type: :model do
    let(:feature_flag) { FeatureFlag.make }

    it { is_expected.to have_timestamp_columns }

    describe "Validations" do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_uniqueness :name }
      it { is_expected.to validate_presence :enabled }
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :name, :enabled }
      it { is_expected.to import_attributes :name, :enabled }
    end
  end
end
