require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition, type: :model do
    let(:quota_definition) { QuotaDefinition.make }

    it_behaves_like "a CloudController model", {
      :required_attributes => [
        :name,
        :non_basic_services_allowed,
        :total_services,
        :memory_limit,
      ],
      :unique_attributes => [:name]
    }

    describe ".default" do
      before { reset_database }

      it "returns the default quota" do
        QuotaDefinition.default.name.should == "free"
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
  end
end
