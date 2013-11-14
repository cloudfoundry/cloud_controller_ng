require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition, type: :model do
    let(:quota_definition) { QuotaDefinition.make }

    it_behaves_like "a CloudController model", {
        required_attributes: [
            :name,
            :non_basic_services_allowed,
            :total_services,
            :total_routes,
            :memory_limit,
        ],
        unique_attributes: [:name],
    }

    describe ".default" do
      it "returns the default quota" do
        QuotaDefinition.default.name.should == "free"
      end
    end

    describe "serialization" do
      {
          name: "foo",
          non_basic_services_allowed: true,
          total_services: 3,
          total_routes: 1000,
          memory_limit: 20,
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
  end
end
