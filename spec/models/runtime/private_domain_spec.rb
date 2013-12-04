require "spec_helper"

module VCAP::CloudController
  describe PrivateDomain, type: :model do
    subject { described_class.make name: "example.com" }

    describe "#as_summary_json" do
      it "returns a hash containing the guid, name, and owning organization guid" do
        expect(subject.as_summary_json).to eq(
          guid: subject.guid,
          name: "example.com",
          owning_organization_guid: subject.owning_organization.guid)
      end
    end

    describe "#validate" do
      include_examples "domain validation"

      context "when an owning organization is not given" do
        before { subject.owning_organization = nil }

        it { should_not be_valid }

        it "fails to validate" do
          subject.validate
          expect(subject.errors[:owning_organization]).to include(:presence)
        end
      end

      context "when the name is foo.com and the same org has bar.foo.com" do
        before do
          PrivateDomain.make name: "bar.foo.com",
                             owning_organization: subject.owning_organization

          subject.name = "foo.com"
        end

        it { should be_valid }
      end

      context "when the name is bar.foo.com and the same org has foo.com" do
        before do
          PrivateDomain.make name: "foo.com",
                             owning_organization: subject.owning_organization

          subject.name = "bar.foo.com"
        end

        it { should be_valid }
      end

      context "when the name is baz.bar.foo.com and the same org has bar.foo.com" do
        before do
          PrivateDomain.make name: "bar.foo.com",
                             owning_organization: subject.owning_organization

          subject.name = "baz.bar.foo.com"
        end

        it { should be_valid }
      end
    end

    describe "#destroy" do
      let(:space) { Space.make(:organization => subject.owning_organization) }

      it "destroys the routes" do
        route = Route.make(domain: subject, space: space)

        expect do
          subject.destroy
        end.to change { Route.where(:id => route.id).count }.by(-1)
      end

      it "nullifies the organization" do
        organization = subject.owning_organization

        expect do
          subject.destroy
        end.to change { organization.reload.private_domains.count }.by(-1)
      end
    end
  end
end
