require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::User, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes          => :guid,
      :unique_attributes            => :guid,
      :many_to_zero_or_one => {
        :default_space => lambda { |user|
          org = user.organizations.first || Organization.make
          Space.make(:organization => org)
        }
      },
      :many_to_zero_or_more => {
        :organizations => lambda { |user| Organization.make },
        :managed_organizations => lambda { |user|
          org = Organization.make
          user.add_organization(org)
          org
        },
        :billing_managed_organizations => lambda { |user|
          org = Organization.make
          user.add_organization(org)
          org
        },
        :audited_organizations => lambda { |user|
          org = Organization.make
          user.add_organization(org)
          org
        },
        :spaces => lambda { |user|
          org = Organization.make
          user.add_organization(org)
          Space.make(:organization => org)
        }
      }
    }

    describe "relationships" do
      let(:org) { Organization.make }
      let(:user) { User.make }

      context "when a user is a member of organzation" do
        before do
          user.add_organization(org)
        end

        it "should allow becoming an organization manager" do
          expect {
            user.add_managed_organization(org)
          }.to change{ user.managed_organizations.size }.by(1)
        end

        it "should allow becoming an organization billing manager" do
          expect {
            user.add_billing_managed_organization(org)
          }.to change{ user.billing_managed_organizations.size }.by(1)
        end

        it "should allow becoming an organization auditor" do
          expect {
            user.add_audited_organization(org)
          }.to change{ user.audited_organizations.size }.by(1)
        end
      end

      context "when a user is not a member of organization" do
        it "should NOT allow becoming an organization manager" do
          expect {
            user.add_audited_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end

        it "should NOT allow becoming an organization billing manager" do
          expect {
            user.add_billing_managed_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end

        it "should NOT allow becoming an organization auditor" do
          expect {
            user.add_audited_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end
    end
  end
end
