require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition, type: :model do
    let(:quota_definition) { QuotaDefinition.make }

    it_behaves_like "a CloudController model", {
    }

    describe "Validations" do
      it { should validate_presence :name }
      it { should validate_presence :non_basic_services_allowed }
      it { should validate_presence :total_services }
      it { should validate_presence :total_routes }
      it { should validate_presence :memory_limit }
      it { should validate_uniqueness :name }
    end

    describe ".default" do
      it "returns the default quota" do
        QuotaDefinition.default.name.should == "default"
      end
    end

    describe "serialization" do
      {
          name: "foo",
          non_basic_services_allowed: true,
          total_services: 3,
          total_routes: 1000,
          memory_limit: 20,
          trial_db_allowed: false,
      }.each do |field, value|
        it "allows export of #{field}" do
          quota_definition.public_send(:"#{field}=", value)
          expect(Yajl::Parser.parse(quota_definition.to_json).fetch(field.to_s)).to eql value
        end
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
          expect(quota_definition.trial_db_allowed).to be_false
        end
      end
    end
  end
end
