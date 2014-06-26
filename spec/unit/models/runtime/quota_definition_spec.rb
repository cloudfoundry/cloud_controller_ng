require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition, type: :model do
    let(:quota_definition) { QuotaDefinition.make }

    it { should have_timestamp_columns }

    describe "Associations" do
      before do
        SecurityContext.stub(:admin?).and_return(true)
      end

      it { should have_associated :organizations }
    end

    describe "Validations" do
      it { should validate_presence :name }
      it { should validate_presence :non_basic_services_allowed }
      it { should validate_presence :total_services }
      it { should validate_presence :total_routes }
      it { should validate_presence :memory_limit }
      it { should validate_uniqueness :name }
    end

    describe "Serialization" do
      it { should export_attributes :name, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit, :trial_db_allowed }
      it { should import_attributes :name, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit, :trial_db_allowed }
    end

    describe ".default" do
      it "returns the default quota" do
        QuotaDefinition.default.name.should == "default"
      end
    end

    describe "#destroy" do
      it "nullifies the organization quota definition" do
        org = Organization.make(:quota_definition => quota_definition)
        expect {
          quota_definition.destroy(savepoint: true)
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
