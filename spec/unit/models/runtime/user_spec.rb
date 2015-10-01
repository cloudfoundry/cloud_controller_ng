require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::User, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :organizations }
      it { is_expected.to have_associated :default_space, class: Space }
      it do
        is_expected.to have_associated :managed_organizations, associated_instance: ->(user) {
          org = Organization.make
          user.add_organization(org)
          org
        }
      end
      it do
        is_expected.to have_associated :billing_managed_organizations, associated_instance: ->(user) {
          org = Organization.make
          user.add_organization(org)
          org
        }
      end
      it do
        is_expected.to have_associated :audited_organizations, associated_instance: ->(user) {
          org = Organization.make
          user.add_organization(org)
          org
        }
      end
      it { is_expected.to have_associated :spaces }
      it { is_expected.to have_associated :managed_spaces, class: Space }
      it { is_expected.to have_associated :audited_spaces, class: Space }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :guid }
      it { is_expected.to validate_uniqueness :guid }
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :admin, :active, :default_space_guid }
      it { is_expected.to import_attributes :guid, :admin, :active, :organization_guids, :managed_organization_guids,
                                    :billing_managed_organization_guids, :audited_organization_guids, :space_guids,
                                    :managed_space_guids, :audited_space_guids, :default_space_guid
      }
    end

    describe '#remove_spaces' do
      let(:org) { Organization.make }
      let(:user) { User.make }
      let(:space) { Space.make }

      before do
        org.add_user(user)
        org.add_space(space)
      end

      context 'when a user is not assigned to any space' do
        it "should not alter a user's developer space" do
          expect {
            user.remove_spaces space
          }.to_not change { user.spaces }
        end

        it "should not alter a user's managed space" do
          expect {
            user.remove_spaces space
          }.to_not change { user.managed_spaces }
        end

        it "should not alter a user's audited spaces" do
          expect {
            user.remove_spaces space
          }.to_not change { user.audited_spaces }
        end
      end

      context 'when a user is assigned to a single space' do
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
          }.to change { user.spaces }.from([space]).to([])
        end

        it "should remove the space from the user's managed spaces" do
          expect {
            user.remove_spaces space
          }.to change { user.managed_spaces }.from([space]).to([])
        end

        it "should remove the space form the user's auditor spaces" do
          expect {
            user.remove_spaces space
          }.to change { user.audited_spaces }.from([space]).to([])
        end

        it "should remove the user from the space's developers role" do
          expect {
            user.remove_spaces space
          }.to change { space.developers }.from([user]).to([])
        end

        it "should remove the user from the space's managers role" do
          expect {
            user.remove_spaces space
          }.to change { space.managers }.from([user]).to([])
        end

        it "should remove the user from the space's auditors role" do
          expect {
            user.remove_spaces space
          }.to change { space.auditors }.from([user]).to([])
        end
      end
    end

    describe 'relationships' do
      let(:org) { Organization.make }
      let(:user) { User.make }

      context 'when a user is a member of organzation' do
        before do
          user.add_organization(org)
        end

        it 'should allow becoming an organization manager' do
          expect {
            user.add_managed_organization(org)
          }.to change { user.managed_organizations.size }.by(1)
        end

        it 'should allow becoming an organization billing manager' do
          expect {
            user.add_billing_managed_organization(org)
          }.to change { user.billing_managed_organizations.size }.by(1)
        end

        it 'should allow becoming an organization auditor' do
          expect {
            user.add_audited_organization(org)
          }.to change { user.audited_organizations.size }.by(1)
        end
      end

      context 'when a user is not a member of organization' do
        it 'should NOT allow becoming an organization manager' do
          expect {
            user.add_audited_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end

        it 'should NOT allow becoming an organization billing manager' do
          expect {
            user.add_billing_managed_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end

        it 'should NOT allow becoming an organization auditor' do
          expect {
            user.add_audited_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end

      context 'when a user is a manager' do
        before do
          user.add_organization(org)
          user.add_managed_organization(org)
        end

        it 'should fail to remove user from organization' do
          expect {
            user.remove_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end

        context 'and they are the only manager of an org' do
          it 'should not allow them to remove the managed_organization' do
            expect {
              user.remove_managed_organization(org)
            }.to raise_error(Sequel::HookFailed)
          end
        end
      end

      context 'when a user is a billing manager' do
        before do
          user.add_organization(org)
          user.add_billing_managed_organization(org)
        end

        it 'should fail to remove user from organization' do
          expect {
            user.remove_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end

      context 'when a user is an auditor' do
        before do
          user.add_organization(org)
          user.add_audited_organization(org)
        end

        it 'should fail to remove user from organization' do
          expect {
            user.remove_organization(org)
          }.to raise_error User::InvalidOrganizationRelation
        end
      end

      context 'when a user is not a manager/billing manager/auditor' do
        before do
          user.add_organization(org)
        end

        it 'should remove user from organization' do
          expect {
            user.remove_organization(org)
          }.to change { user.organizations.size }.by(-1)
        end
      end
    end

    describe '#export_attrs' do
      let(:user) { User.make }

      it 'does not include username when username has not been set' do
        expect(user.export_attrs).to_not include(:username)
      end

      it 'includes username when username has been set' do
        user.username = 'somebody'
        expect(user.export_attrs).to include(:username)
      end

      context 'organization_roles' do
        it 'does not include organization_roles when organization_roles has not been set' do
          expect(user.export_attrs).to_not include(:organization_roles)
        end

        it 'includes organization_roles when organization_roles has been set' do
          user.organization_roles = 'something'
          expect(user.export_attrs).to include(:organization_roles)
        end
      end

      context 'space_roles' do
        it 'does not include space_roles when space_roles has not been set' do
          expect(user.export_attrs).to_not include(:space_roles)
        end

        it 'includes space_roles when space_roles has been set' do
          user.space_roles = 'something'
          expect(user.export_attrs).to include(:space_roles)
        end
      end
    end

    describe '#membership_spaces' do
      it 'returns a list of spaces that the user is a member of' do
        user = User.make
        organization = Organization.make
        organization.add_user user
        developer_space = Space.make organization: organization
        auditor_space = Space.make organization: organization
        manager_space = Space.make organization: organization

        manager_space.add_manager user
        auditor_space.add_auditor user
        developer_space.add_developer user

        ids = user.membership_spaces.all.map(&:id)

        expect(ids).to match_array([developer_space, manager_space, auditor_space].map(&:id))
      end
    end
  end
end
