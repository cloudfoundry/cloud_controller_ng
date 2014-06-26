require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceAuthToken, type: :model do

    it_behaves_like "a model with an encrypted attribute" do
      let(:encrypted_attr) { :token }
    end

    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it { is_expected.to have_associated :service }
    end

    describe "Validations" do
      it { is_expected.to validate_presence :label }
      it { is_expected.to validate_presence :provider }
      it { is_expected.to validate_presence :token }
      it { is_expected.to validate_uniqueness [:label, :provider] }
      it { is_expected.to strip_whitespace :label }
      it { is_expected.to strip_whitespace :provider }
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :label, :provider }
      it { is_expected.to import_attributes :label, :provider, :token }
    end
  end
end
