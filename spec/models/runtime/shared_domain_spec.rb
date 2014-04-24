require "spec_helper"

module VCAP::CloudController
  describe SharedDomain, type: :model do
    subject { described_class.make name: "example.com" }

    describe "#as_summary_json" do
      it "returns a hash containing the guid and name" do
        expect(subject.as_summary_json).to eq(
                                             guid: subject.guid,
                                             name: "example.com")
      end
    end

    describe "#validate" do
      include_examples "domain validation"
    end

    describe "#destroy" do
      it "destroys the routes" do
        route = Route.make(domain: subject)

        expect do
          subject.destroy
        end.to change { Route.where(:id => route.id).count }.by(-1)
      end
    end

    describe "addable_to_organization!" do
      it "does not raise error" do
        expect{subject.addable_to_organization!(Organization.new)}.to_not raise_error
      end
    end
  end
end
