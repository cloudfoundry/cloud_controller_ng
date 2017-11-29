require 'spec_helper'

module VCAP::CloudController::Perm
  RSpec.describe Permissions do
    let(:perm_client) { instance_double(VCAP::CloudController::Perm::Client) }
    let(:user_id) { 'test-user-id' }
    let(:issuer) { 'test-issuer' }
    let(:roles) { instance_double(VCAP::CloudController::Roles) }
    let(:org_id) { 'test-org-id' }
    let(:space_id) { 'test-space-id' }
    subject(:permissions) {
      VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)
    }

    describe '#can_read_globally?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        expect(permissions.can_read_globally?).to eq(true)
      end

      it 'returns true when the user is a read-only admin' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        expect(permissions.can_read_globally?).to eq(true)
      end

      it 'returns true when the user is a global auditor' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        expect(permissions.can_read_globally?).to eq(true)
      end

      it 'returns false otherwise' do
        expect(permissions.can_read_globally?).to eq(false)
      end
    end

    describe '#can_write_globally?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        expect(permissions.can_write_globally?).to eq(true)
      end

      it 'returns false otherwise' do
        expect(permissions.can_write_globally?).to eq(false)
      end
    end

    describe '#can_read_from_space?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
        allow(perm_client).to receive(:has_any_permission?).with(permissions: anything, user_id: anything, issuer: anything).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        has_permission = permissions.can_read_from_space?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user is a read-only admin' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        has_permission = permissions.can_read_from_space?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user is a global auditor' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        has_permission = permissions.can_read_from_space?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user has a relevant permission' do
        expected_permissions = [
          { permission_name: 'space.developer', resource_id: space_id },
          { permission_name: 'space.manager', resource_id: space_id },
          { permission_name: 'space.auditor', resource_id: space_id },
          { permission_name: 'org.manager', resource_id: org_id },
        ]

        allow(perm_client).to receive(:has_any_permission?).with(permissions: expected_permissions, user_id: user_id, issuer: issuer).and_return(true)

        has_permission = permissions.can_read_from_space?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns false otherwise' do
        has_permission = permissions.can_read_from_space?(space_id, org_id)

        expect(has_permission).to equal(false)
      end
    end
  end
end
