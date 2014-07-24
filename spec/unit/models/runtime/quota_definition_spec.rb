require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition, type: :model do
    let(:quota_definition) { QuotaDefinition.make }

    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      before do
        allow(SecurityContext).to receive(:admin?).and_return(true)
      end

      it { is_expected.to have_associated :organizations }
    end

    describe "Validations" do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :non_basic_services_allowed }
      it { is_expected.to validate_presence :total_services }
      it { is_expected.to validate_presence :total_routes }
      it { is_expected.to validate_presence :memory_limit }
      it { is_expected.to validate_uniqueness :name }

      describe "memory_limit" do
        it "cannot be less than zero" do
          quota_definition.memory_limit = -1
          expect(quota_definition).not_to be_valid
          expect(quota_definition.errors.on(:memory_limit)).to include(:less_than_zero)

          quota_definition.memory_limit = 0
          expect(quota_definition).to be_valid
        end
      end
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :name, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit, :trial_db_allowed, :instance_memory_limit }
      it { is_expected.to import_attributes :name, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit, :trial_db_allowed, :instance_memory_limit }
    end

    describe ".default" do
      it "returns the default quota" do
        expect(QuotaDefinition.default.name).to eq("default")
      end
    end

    describe "#destroy" do
      it "nullifies the organization quota definition" do
        org = Organization.make(:quota_definition => quota_definition)
        expect {
          quota_definition.destroy
        }.to change {
          Organization.count(:id => org.id)
        }.by(-1)
      end
    end

    describe "#trial_db_allowed=" do
      it "can be called on the model object" do
        quota_definition.trial_db_allowed = true
      end

      it "will not change the value returned (deprecated)" do
        expect {
          quota_definition.trial_db_allowed = true
        }.to_not change {
          quota_definition
        }
      end
    end

    describe "#trial_db_allowed" do
      it "always returns false (deprecated)" do
        [false, true].each do |allowed|
          quota_definition.trial_db_allowed = allowed
          expect(quota_definition.trial_db_allowed).to be false
        end
      end
    end
  end
end
