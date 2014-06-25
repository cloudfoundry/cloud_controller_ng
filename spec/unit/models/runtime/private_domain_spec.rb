require "spec_helper"

module VCAP::CloudController
  describe PrivateDomain, type: :model do
    subject { described_class.make name: "test.example.com" }

    it { should have_timestamp_columns }

    describe "Serialization" do
      it { should export_attributes :name, :owning_organization_guid }
      it { should import_attributes :name, :owning_organization_guid }
    end

    describe "#as_summary_json" do
      it "returns a hash containing the guid, name, and owning organization guid" do
        expect(subject.as_summary_json).to eq(
          guid: subject.guid,
          name: "test.example.com",
          owning_organization_guid: subject.owning_organization.guid)
      end
    end

    describe "#in_suspended_org?" do
      let(:org) { Organization.make }
      subject(:private_domain) { PrivateDomain.new(owning_organization: org) }

      context "when in a suspended organization" do
        before { allow(org).to receive(:suspended?).and_return(true) }
        it "is true" do
          expect(private_domain).to be_in_suspended_org
        end
      end

      context "when in an un-suspended organization" do
        before { allow(org).to receive(:suspended?).and_return(false) }
        it "is false" do
          expect(private_domain).not_to be_in_suspended_org
        end
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
      
      context "when the name is foo.com and shared domains has bar.foo.com" do
        before do
          SharedDomain.make name: "bar.foo.com"
        end

        it "raises a validation error" do
           expect {
             PrivateDomain.make name: "foo.com"
           }.to raise_error Sequel::ValidationFailed, /overlapping_domain/
        end
      end

      context "when the name is pans.com and shared domains has my.potsandpans.com" do
        before do
          SharedDomain.make name: "my.potsandpans.com"
          subject.name = "pans.com"
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
    end

    describe "addable_to_organization!" do
      it "raises error when the domain belongs to a different org" do
        expect{subject.addable_to_organization!(Organization.new)}.to raise_error(Domain::UnauthorizedAccessToPrivateDomain)
      end

      it "does not raise error when the domain belongs to a different org" do
        expect{subject.addable_to_organization!(subject.owning_organization)}.to_not raise_error
      end
    end
  end
end
