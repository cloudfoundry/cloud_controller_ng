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

    describe '#can_read_secrets_globally?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        expect(permissions.can_read_secrets_globally?).to eq(true)
      end

      it 'returns true when the user is a read-only admin' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        expect(permissions.can_read_secrets_globally?).to eq(true)
      end

      it 'returns false otherwise' do
        expect(permissions.can_read_secrets_globally?).to eq(false)
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

    describe '#can_read_from_org?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
        allow(perm_client).to receive(:has_any_permission?).with(permissions: anything, user_id: anything, issuer: anything).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        has_permission = permissions.can_read_from_org?(org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user is a read-only admin' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        has_permission = permissions.can_read_from_org?(org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user is a global auditor' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        has_permission = permissions.can_read_from_org?(org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user has any relevant permission' do
        expected_permissions = [
          { action: 'org.manager', resource: org_id },
          { action: 'org.auditor', resource: org_id },
          { action: 'org.user', resource: org_id },
          { action: 'org.billing_manager', resource: org_id },
        ]

        allow(perm_client).to receive(:has_any_permission?).with(permissions: expected_permissions, user_id: user_id, issuer: issuer).and_return(true)

        has_permission = permissions.can_read_from_org?(org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns false otherwise' do
        has_permission = permissions.can_read_from_org?(org_id)

        expect(has_permission).to equal(false)
      end
    end

    describe '#can_write_to_org?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(perm_client).to receive(:has_any_permission?).with(permissions: anything, user_id: anything, issuer: anything).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        has_permission = permissions.can_write_to_org?(org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user has any relevant permission' do
        expected_permissions = [
          { action: 'org.manager', resource: org_id },
        ]

        allow(perm_client).to receive(:has_any_permission?).with(permissions: expected_permissions, user_id: user_id, issuer: issuer).and_return(true)

        has_permission = permissions.can_write_to_org?(org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns false otherwise' do
        has_permission = permissions.can_write_to_org?(org_id)

        expect(has_permission).to equal(false)
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

      it 'returns true when the user has any relevant permission' do
        expected_permissions = [
          { action: 'space.developer', resource: space_id },
          { action: 'space.manager', resource: space_id },
          { action: 'space.auditor', resource: space_id },
          { action: 'org.manager', resource: org_id },
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

    describe '#can_read_secrets_in_space?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(perm_client).to receive(:has_any_permission?).with(permissions: anything, user_id: anything, issuer: anything).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        has_permission = permissions.can_read_secrets_in_space?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user is a read-only admin' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        has_permission = permissions.can_read_secrets_in_space?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user has any relevant permission' do
        expected_permissions = [
          { action: 'space.developer', resource: space_id }
        ]

        allow(perm_client).to receive(:has_any_permission?).with(permissions: expected_permissions, user_id: user_id, issuer: issuer).and_return(true)

        has_permission = permissions.can_read_secrets_in_space?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns false otherwise' do
        has_permission = permissions.can_read_secrets_in_space?(space_id, org_id)

        expect(has_permission).to equal(false)
      end
    end

    describe '#can_write_to_space?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(perm_client).to receive(:has_any_permission?).with(permissions: anything, user_id: anything, issuer: anything).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        has_permission = permissions.can_write_to_space?(space_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user has any relevant permission' do
        expected_permissions = [
          { action: 'space.developer', resource: space_id }
        ]

        allow(perm_client).to receive(:has_any_permission?).with(permissions: expected_permissions, user_id: user_id, issuer: issuer).and_return(true)

        has_permission = permissions.can_write_to_space?(space_id)

        expect(has_permission).to equal(true)
      end

      it 'returns false otherwise' do
        has_permission = permissions.can_write_to_space?(space_id)

        expect(has_permission).to equal(false)
      end
    end

    describe '#can_read_from_isolation_segment?' do
      let(:isolation_segment) { spy('IsolationSegment') }

      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
        allow(isolation_segment).to receive(:organizations).and_return([])
        allow(isolation_segment).to receive(:spaces).and_return([])
        allow(perm_client).to receive(:has_any_permission?).with(permissions: anything, user_id: anything, issuer: anything).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        has_permission = permissions.can_read_from_isolation_segment?(isolation_segment)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user is a read-only admin' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        has_permission = permissions.can_read_from_isolation_segment?(isolation_segment)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user is a global auditor' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        has_permission = permissions.can_read_from_isolation_segment?(isolation_segment)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user has any spaces with relevant permission' do
        organization = spy('Organization', guid: 'some-org-id')
        space = spy('Space', guid: 'some-space-id', organization: organization)

        allow(perm_client).to receive(:has_any_permission?).and_return(true)
        allow(isolation_segment).to receive(:spaces).and_return([space])

        has_permission = permissions.can_read_from_isolation_segment?(isolation_segment)

        expected_permissions = [
          { action: 'space.developer', resource: 'some-space-id' },
          { action: 'space.manager', resource: 'some-space-id' },
          { action: 'space.auditor', resource: 'some-space-id' },
          { action: 'org.manager', resource: 'some-org-id' },
        ]

        expect(has_permission).to equal(true)
        expect(perm_client).to have_received(:has_any_permission?).with(
          permissions: expected_permissions,
          user_id: user_id,
          issuer: issuer
        )
      end

      it 'returns true when the user has any organizations with relevant permission' do
        organization = spy('Organization', guid: 'some-org-id')

        allow(perm_client).to receive(:has_any_permission?).and_return(true)
        allow(isolation_segment).to receive(:organizations).and_return([organization])

        has_permission = permissions.can_read_from_isolation_segment?(isolation_segment)

        expected_permissions = [
          { action: 'org.manager', resource: 'some-org-id' },
          { action: 'org.auditor', resource: 'some-org-id' },
          { action: 'org.user', resource: 'some-org-id' },
          { action: 'org.billing_manager', resource: 'some-org-id' },
        ]

        expect(has_permission).to equal(true)
        expect(perm_client).to have_received(:has_any_permission?).with(
          permissions: expected_permissions,
          user_id: user_id,
          issuer: issuer
        )
      end

      it 'returns false otherwise' do
        has_permission = permissions.can_read_from_isolation_segment?(isolation_segment)

        expect(has_permission).to equal(false)
      end
    end

    describe '#can_read_route?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
        allow(perm_client).to receive(:has_any_permission?).with(permissions: anything, user_id: anything, issuer: anything).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        has_permission = permissions.can_read_route?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user is a read-only admin' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        has_permission = permissions.can_read_route?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user is a global auditor' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        has_permission = permissions.can_read_route?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user has any relevant permission' do
        expected_permissions = [
          { action: 'space.developer', resource: space_id },
          { action: 'space.manager', resource: space_id },
          { action: 'space.auditor', resource: space_id },
          { action: 'org.manager', resource: org_id },
          { action: 'org.auditor', resource: org_id },
        ]

        allow(perm_client).to receive(:has_any_permission?).with(permissions: expected_permissions, user_id: user_id, issuer: issuer).and_return(true)

        has_permission = permissions.can_read_route?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns false otherwise' do
        has_permission = permissions.can_read_route?(space_id, org_id)

        expect(has_permission).to equal(false)
      end
    end
  end
end
