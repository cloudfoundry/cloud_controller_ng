require 'spec_helper'

module VCAP::CloudController
  RSpec.describe OrganizationUser, type: :model do
    let(:organization) { Organization.make }
    let(:user) { User.make }

    describe 'Validations' do
      it { is_expected.to validate_uniqueness [:organization_id, :user_id] }
      it { is_expected.to validate_presence :organization_id }
      it { is_expected.to validate_presence :user_id }

      it { is_expected.to have_timestamp_columns }
    end

    it 'can be created' do
      OrganizationUser.create(organization_id: organization.id, user_id: user.id)

      role_found = OrganizationUser.find(organization_id: organization.id, user_id: user.id)

      expect(role_found.guid).to be_a_guid
      expect(role_found.created_at).to be_a Time
      expect(role_found.updated_at).to be_a Time
      expect(role_found.type).to eq(RoleTypes::ORGANIZATION_USER)
      expect(role_found.organization_id).to eq organization.id
      expect(role_found.user_id).to eq user.id
    end

    it 'can be used to retrieve user guid' do
      OrganizationUser.create(organization_id: organization.id, user_id: user.id)
      role_found = OrganizationUser.find(organization_id: organization.id, user_id: user.id)

      expect(role_found.user).to eq user
    end
  end
end
