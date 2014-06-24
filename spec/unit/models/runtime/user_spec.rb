require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::User, type: :model do
    it_behaves_like "a CloudController model", {
      :extra_json_attributes => [:guid],
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

    describe "Validations" do
      it { should validate_presence :guid }
      it { should validate_uniqueness :guid }
    end


    describe "#remove_spaces" do
      let(:org) { Organization.make }
      let(:user) { User.make }
      let(:space) { Space.make }

      before do
        org.add_user(user)
        org.add_space(space)
      end

      context "when a user is not assigned to any space" do
        it "should not alter a user's developer space" do
          expect {
            user.remove_spaces space
          }.to_not change{ user.spaces }
        end

        it "should not alter a user's managed space" do
          expect {
            user.remove_spaces space
          }.to_not change{ user.managed_spaces }
        end

        it "should not alter a user's audited spaces" do
          expect {
            user.remove_spaces space
          }.to_not change{ user.audited_spaces }
        end
      end

      context "when a user is assigned to a single space" do
        before do
          space.add_developer(user)
          space.add_manager(user)
          space.add_auditor(user)
          user.refresh
          space.refresh
        end

        it "should remove the space from the user's developer spaces" do
          expect {
            user.remove_spaces space
          }.to change{ user.spaces }.from([space]).to([])
        end

        it "should remove the space from the user's managed spaces" do
          expect {
            user.remove_spaces space
          }.to change{ user.managed_spaces }.from([space]).to([])
        end

        it "should remove the space form the user's auditor spaces" do
          expect {
            user.remove_spaces space
          }.to change{ user.audited_spaces }.from([space]).to([])
        end

        it "should remove the user from the space's developers role" do
          expect {
            user.remove_spaces space
          }.to change{ space.developers }.from([user]).to([])
        end

        it "should remove the user from the space's managers role" do
          expect {
            user.remove_spaces space
          }.to change{ space.managers }.from([user]).to([])
        end

        it "should remove the user from the space's auditors role" do
          expect {
            user.remove_spaces space
          }.to change{ space.auditors }.from([user]).to([])
        end
      end
    end

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

      context "when a user is a manager" do
        before do
          user.add_organization(org)
          user.add_managed_organization(org)
        end

        it "should fail to remove user from organization" do
          expect {
            user.remove_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end

        context "and they are the only manager of an org" do
          it "should not allow them to remove the managed_organization" do
            expect {
              user.remove_managed_organization(org)
            }.to raise_error(Sequel::HookFailed)
          end
        end
      end

      context "when a user is a billing manager" do
        before do
          user.add_organization(org)
          user.add_billing_managed_organization(org)
        end

        it "should fail to remove user from organization" do
          expect {
            user.remove_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end

      context "when a user is an auditor" do
        before do
          user.add_organization(org)
          user.add_audited_organization(org)
        end

        it "should fail to remove user from organization" do
          expect {
            user.remove_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end

      context "when a user is not a manager/billing manager/auditor" do
        before do
          user.add_organization(org)
        end

        it "should remove user from organization" do
          expect {
            user.remove_organization(org)
          }.to change{user.organizations.size}.by(-1)
        end
      end
    end
  end
end
