require "spec_helper"

module VCAP::CloudController
  describe PrivateDomain, type: :model do
    let(:private_domain) { described_class.make name: "test.example.com" }

    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it "has associated spaces" do
        private_domain = PrivateDomain.make
        space = Space.make(organization: private_domain.owning_organization)
        expect(private_domain.spaces).to include(space.reload)
      end

      context "changing owning_organization" do
        it "succeeds when there are no existing routes" do
          expect{ private_domain.owning_organization = Organization.make }.not_to raise_error
        end

        it "fails when there are existing routes" do
          route = Route.make
          expect{ route.domain.owning_organization = Organization.make }.to raise_error VCAP::Errors::ApiError, /delete the routes associations/
        end
      end

    end

    describe "Serialization" do
      it { is_expected.to export_attributes :name, :owning_organization_guid }
      it { is_expected.to import_attributes :name, :owning_organization_guid }
    end

    describe "Validations" do
      it { is_expected.to validate_presence :owning_organization }

      describe "domain" do
        subject { private_domain }
        include_examples "domain validation"
      end
    end

    describe "#as_summary_json" do
      it "returns a hash containing the guid, name, and owning organization guid" do
        expect(private_domain.as_summary_json).to eq(
          guid: private_domain.guid,
          name: "test.example.com",
          owning_organization_guid: private_domain.owning_organization.guid)
      end
    end

    describe "#in_suspended_org?" do
      let(:org) { Organization.make }
      let(:private_domain) { PrivateDomain.new(owning_organization: org) }

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

    describe "#destroy" do
      let(:space) { Space.make(:organization => private_domain.owning_organization) }

      it "destroys the routes" do
        route = Route.make(domain: private_domain, space: space)

        expect do
          private_domain.destroy
        end.to change { Route.where(:id => route.id).count }.by(-1)
      end
    end

    describe "addable_to_organization!" do
      it "raises error when the domain belongs to a different org" do
        expect{
          private_domain.addable_to_organization!(Organization.new)
        }.to raise_error(Domain::UnauthorizedAccessToPrivateDomain)
      end

      it "does not raise error when the domain belongs to a different org" do
        expect {
          private_domain.addable_to_organization!(private_domain.owning_organization)
        }.to_not raise_error
      end
    end
  end
end
