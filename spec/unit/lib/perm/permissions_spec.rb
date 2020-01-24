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

    describe '#readable_org_guids' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
      end

      it 'returns all org guids for admins' do
        allow(roles).to receive(:admin?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make

        org_guids = permissions.readable_org_guids

        expect(org_guids).to include(org1.guid)
        expect(org_guids).to include(org2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all org guids for read-only admins' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make

        org_guids = permissions.readable_org_guids

        expect(org_guids).to include(org1.guid)
        expect(org_guids).to include(org2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all org guids for global auditors' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make

        org_guids = permissions.readable_org_guids

        expect(org_guids).to include(org1.guid)
        expect(org_guids).to include(org2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns the list of org guids that the user can read' do
        readable_org_guids = [SecureRandom.uuid, SecureRandom.uuid]

        actions = %w(org.manager org.billing_manager org.auditor org.user)
        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: actions).
          and_return(readable_org_guids)

        expect(permissions.readable_org_guids).to match_array(readable_org_guids)
      end
    end

    describe '#readable_org_contents_org_guids' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
      end

      it 'returns all org guids for admins' do
        allow(roles).to receive(:admin?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make

        org_guids = permissions.readable_org_contents_org_guids

        expect(org_guids).to include(org1.guid)
        expect(org_guids).to include(org2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all org guids for read-only admins' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make

        org_guids = permissions.readable_org_contents_org_guids

        expect(org_guids).to include(org1.guid)
        expect(org_guids).to include(org2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all org guids for global auditors' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make

        org_guids = permissions.readable_org_contents_org_guids

        expect(org_guids).to include(org1.guid)
        expect(org_guids).to include(org2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns the list of org guids where the user has full read access to the org and its contents' do
        readable_org_guids = [SecureRandom.uuid, SecureRandom.uuid]

        actions = %w(org.manager)
        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: actions).
          and_return(readable_org_guids)

        expect(permissions.readable_org_contents_org_guids).to match_array(readable_org_guids)
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

    describe '#readable_space_guids' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
      end

      it 'returns all space guids for admins' do
        allow(roles).to receive(:admin?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)

        space_guids = permissions.readable_space_guids

        expect(space_guids).to include(space1.guid)
        expect(space_guids).to include(space2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all space guids for read-only admins' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)

        space_guids = permissions.readable_space_guids

        expect(space_guids).to include(space1.guid)
        expect(space_guids).to include(space2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all space guids for global auditors' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)

        space_guids = permissions.readable_space_guids

        expect(space_guids).to include(space1.guid)
        expect(space_guids).to include(space2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns the list of space guids that the user can read via space roles and as an org manager without duplicates' do
        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make
        managed_org_guids = [org1.guid, org2.guid]

        space1 = VCAP::CloudController::Space.make(organization: org1)
        space2 = VCAP::CloudController::Space.make(organization: org1)
        space3 = VCAP::CloudController::Space.make(organization: org2)
        space4 = VCAP::CloudController::Space.make(organization: org2)

        managed_org_space_guids = [space1.guid, space2.guid, space3.guid, space4.guid]
        org_actions = %w(org.manager)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: org_actions).
          and_return(managed_org_guids)

        readable_space_guids = [SecureRandom.uuid, SecureRandom.uuid]
        space_actions = %w(space.developer space.manager space.auditor)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: space_actions).
          and_return(readable_space_guids + [space1.guid, space4.guid])

        expected_space_guids = managed_org_space_guids + readable_space_guids

        expect(permissions.readable_space_guids).to match_array(expected_space_guids)
      end
    end

    describe '#readable_secret_space_guids' do
      let(:permissions) do
        VCAP::CloudController::Perm::Permissions.new(
          perm_client: perm_client,
          user_id: user_id,
          issuer: issuer,
          roles: roles,
        )
      end

      let!(:org1) { VCAP::CloudController::Organization.make }
      let!(:space1) { VCAP::CloudController::Space.make(organization: org1) }
      let!(:org2) { VCAP::CloudController::Organization.make }
      let!(:space2) { VCAP::CloudController::Space.make(organization: org2) }

      let(:needed_space_actions) { %w(space.developer) }

      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: []).
          and_return([])
      end

      it 'returns space_guids that user has a space.developer permission for' do
        returned_space_guids = ['some-space-id-1', 'some-space-id-2']

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: needed_space_actions).
          and_return(returned_space_guids)

        space_guids = permissions.readable_secret_space_guids

        expect(space_guids).to eq(returned_space_guids)
      end

      it 'returns all space guids for admins' do
        allow(roles).to receive(:admin?).and_return(true)

        space_guids = permissions.readable_secret_space_guids

        expect(space_guids).to include(space1.guid)
        expect(space_guids).to include(space2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all space guids for read-only admins' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        space_guids = permissions.readable_secret_space_guids

        expect(space_guids).to include(space1.guid)
        expect(space_guids).to include(space2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'does not return any space_guids for global_auditor' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: needed_space_actions).
          and_return([])

        space_guids = permissions.readable_secret_space_guids

        expect(space_guids).to be_empty

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end
    end

    describe '#readable_space_scoped_space_guids' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
      end

      it 'returns space guids that the user can read via space roles' do
        space_actions = %w(space.developer space.manager space.auditor)

        expected_space_guids = [SecureRandom.uuid, SecureRandom.uuid]

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: space_actions).
          and_return(expected_space_guids)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: []).
          and_return([])

        expect(permissions.readable_space_scoped_space_guids).to match_array(expected_space_guids)
      end

      [:admin?, :admin_read_only?, :global_auditor?].each do |role|
        it "returns all space guids for #{role}" do
          allow(roles).to receive(role).and_return(true)

          permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)
          space1 = VCAP::CloudController::Space.make
          space2 = VCAP::CloudController::Space.make

          space_guids = permissions.readable_space_scoped_space_guids

          expect(space_guids).to contain_exactly(space1.guid, space2.guid)

          expect(perm_client).not_to receive(:list_unique_resource_patterns)
        end
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

    describe '#can_update_space?' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(perm_client).to receive(:has_any_permission?).with(permissions: anything, user_id: anything, issuer: anything).and_return(false)
      end

      it 'returns true when the user is an admin' do
        allow(roles).to receive(:admin?).and_return(true)

        has_permission = permissions.can_update_space?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns true when the user has any relevant permission' do
        expected_permissions = [
          { action: 'space.manager', resource: space_id }
        ]

        allow(perm_client).to receive(:has_any_permission?).with(permissions: expected_permissions, user_id: user_id, issuer: issuer).and_return(true)

        has_permission = permissions.can_update_space?(space_id, org_id)

        expect(has_permission).to equal(true)
      end

      it 'returns false otherwise' do
        has_permission = permissions.can_update_space?(space_id, org_id)

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

    describe '#readable_route_guids' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
      end

      it 'returns all route guids for admins' do
        allow(roles).to receive(:admin?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        route1 = VCAP::CloudController::Route.make(space: space1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)
        route2 = VCAP::CloudController::Route.make(space: space2)

        route_guids = permissions.readable_route_guids

        expect(route_guids).to include(route1.guid)
        expect(route_guids).to include(route2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all route guids for read-only admins' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        route1 = VCAP::CloudController::Route.make(space: space1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)
        route2 = VCAP::CloudController::Route.make(space: space2)

        route_guids = permissions.readable_route_guids

        expect(route_guids).to include(route1.guid)
        expect(route_guids).to include(route2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all route guids for global auditors' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        route1 = VCAP::CloudController::Route.make(space: space1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)
        route2 = VCAP::CloudController::Route.make(space: space2)

        route_guids = permissions.readable_route_guids

        expect(route_guids).to include(route1.guid)
        expect(route_guids).to include(route2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns the list of route guids that the user can read via org and space roles' do
        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make
        org_guids = [org1.guid, org2.guid]

        space1 = VCAP::CloudController::Space.make(organization: org1)
        route1 = VCAP::CloudController::Route.make(space: space1)
        route2 = VCAP::CloudController::Route.make(space: space1)

        space2 = VCAP::CloudController::Space.make(organization: org2)
        route3 = VCAP::CloudController::Route.make(space: space2)

        org_route_guids = [route1.guid, route2.guid, route3.guid]
        org_actions = %w(org.manager org.auditor)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: org_actions).
          and_return(org_guids)

        org3 = VCAP::CloudController::Organization.make
        space3 = VCAP::CloudController::Space.make(organization: org3)
        route4 = VCAP::CloudController::Route.make(space: space3)
        space4 = VCAP::CloudController::Space.make(organization: org3)
        route5 = VCAP::CloudController::Route.make(space: space4)

        readable_space_guids = [space3.guid, space4.guid]
        readable_route_guids = [route4.guid, route5.guid]
        space_actions = %w(space.developer space.manager space.auditor)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: space_actions).
          and_return(readable_space_guids)

        expected_route_guids = org_route_guids + readable_route_guids

        expect(permissions.readable_route_guids).to match_array(expected_route_guids)
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

    describe '#readable_app_guids' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
      end

      it 'returns all app guids for admins' do
        allow(roles).to receive(:admin?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        app1 = VCAP::CloudController::AppModel.make(space: space1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)
        app2 = VCAP::CloudController::AppModel.make(space: space2)

        app_guids = permissions.readable_app_guids

        expect(app_guids).to include(app1.guid)
        expect(app_guids).to include(app2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all app guids for read-only admins' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        app1 = VCAP::CloudController::AppModel.make(space: space1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)
        app2 = VCAP::CloudController::AppModel.make(space: space2)

        app_guids = permissions.readable_app_guids

        expect(app_guids).to include(app1.guid)
        expect(app_guids).to include(app2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all app guids for global auditors' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        app1 = VCAP::CloudController::AppModel.make(space: space1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)
        app2 = VCAP::CloudController::AppModel.make(space: space2)

        app_guids = permissions.readable_app_guids

        expect(app_guids).to include(app1.guid)
        expect(app_guids).to include(app2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns the list of app guids that the user can read via org and space roles' do
        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make
        org_guids = [org1.guid, org2.guid]

        space1 = VCAP::CloudController::Space.make(organization: org1)
        app1 = VCAP::CloudController::AppModel.make(space: space1)
        app2 = VCAP::CloudController::AppModel.make(space: space1)

        space2 = VCAP::CloudController::Space.make(organization: org2)
        app3 = VCAP::CloudController::AppModel.make(space: space2)

        org_app_guids = [app1.guid, app2.guid, app3.guid]
        org_actions = %w(org.manager)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: org_actions).
          and_return(org_guids)

        org3 = VCAP::CloudController::Organization.make
        space3 = VCAP::CloudController::Space.make(organization: org3)
        app4 = VCAP::CloudController::AppModel.make(space: space3)
        space4 = VCAP::CloudController::Space.make(organization: org3)
        app5 = VCAP::CloudController::AppModel.make(space: space4)

        readable_space_guids = [space3.guid, space4.guid]
        readable_app_guids = [app4.guid, app5.guid]
        space_actions = %w(space.developer space.manager space.auditor)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: space_actions).
          and_return(readable_space_guids)

        expected_app_guids = org_app_guids + readable_app_guids

        expect(permissions.readable_app_guids).to match_array(expected_app_guids)
      end
    end

    describe '#readable_route_mapping_guids' do
      before do
        allow(roles).to receive(:admin?).and_return(false)
        allow(roles).to receive(:admin_read_only?).and_return(false)
        allow(roles).to receive(:global_auditor?).and_return(false)
      end

      it 'returns all route mapping guids for admins' do
        allow(roles).to receive(:admin?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        app1 = VCAP::CloudController::AppModel.make(space: space1)
        route_mapping1 = VCAP::CloudController::RouteMappingModel.make(app: app1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)
        app2 = VCAP::CloudController::AppModel.make(space: space2)
        route_mapping2 = VCAP::CloudController::RouteMappingModel.make(app: app2)

        route_mapping_guids = permissions.readable_route_mapping_guids

        expect(route_mapping_guids).to include(route_mapping1.guid)
        expect(route_mapping_guids).to include(route_mapping2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all route mapping guids for read-only admins' do
        allow(roles).to receive(:admin_read_only?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        app1 = VCAP::CloudController::AppModel.make(space: space1)
        route_mapping1 = VCAP::CloudController::RouteMappingModel.make(app: app1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)
        app2 = VCAP::CloudController::AppModel.make(space: space2)
        route_mapping2 = VCAP::CloudController::RouteMappingModel.make(app: app2)

        route_mapping_guids = permissions.readable_route_mapping_guids

        expect(route_mapping_guids).to include(route_mapping1.guid)
        expect(route_mapping_guids).to include(route_mapping2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns all route mapping guids for global auditors' do
        allow(roles).to receive(:global_auditor?).and_return(true)

        permissions = VCAP::CloudController::Perm::Permissions.new(perm_client: perm_client, user_id: user_id, issuer: issuer, roles: roles)

        org1 = VCAP::CloudController::Organization.make
        space1 = VCAP::CloudController::Space.make(organization: org1)
        app1 = VCAP::CloudController::AppModel.make(space: space1)
        route_mapping1 = VCAP::CloudController::RouteMappingModel.make(app: app1)
        org2 = VCAP::CloudController::Organization.make
        space2 = VCAP::CloudController::Space.make(organization: org2)
        app2 = VCAP::CloudController::AppModel.make(space: space2)
        route_mapping2 = VCAP::CloudController::RouteMappingModel.make(app: app2)

        route_mapping_guids = permissions.readable_route_mapping_guids

        expect(route_mapping_guids).to include(route_mapping1.guid)
        expect(route_mapping_guids).to include(route_mapping2.guid)

        expect(perm_client).not_to receive(:list_unique_resource_patterns)
      end

      it 'returns the list of route mapping guids that the user can read via org and space roles' do
        org1 = VCAP::CloudController::Organization.make
        org2 = VCAP::CloudController::Organization.make
        org_guids = [org1.guid, org2.guid]

        space1 = VCAP::CloudController::Space.make(organization: org1)
        app1 = VCAP::CloudController::AppModel.make(space: space1)
        route_mapping1 = VCAP::CloudController::RouteMappingModel.make(app: app1)
        app2 = VCAP::CloudController::AppModel.make(space: space1)
        route_mapping2 = VCAP::CloudController::RouteMappingModel.make(app: app2)

        space2 = VCAP::CloudController::Space.make(organization: org2)
        app3 = VCAP::CloudController::AppModel.make(space: space2)
        route_mapping3 = VCAP::CloudController::RouteMappingModel.make(app: app3)

        org_route_mapping_guids = [route_mapping1.guid, route_mapping2.guid, route_mapping3.guid]
        org_actions = %w(org.manager)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: org_actions).
          and_return(org_guids)

        org3 = VCAP::CloudController::Organization.make
        space3 = VCAP::CloudController::Space.make(organization: org3)
        app4 = VCAP::CloudController::AppModel.make(space: space3)
        route_mapping4 = VCAP::CloudController::RouteMappingModel.make(app: app4)
        space4 = VCAP::CloudController::Space.make(organization: org3)
        app5 = VCAP::CloudController::AppModel.make(space: space4)
        route_mapping5 = VCAP::CloudController::RouteMappingModel.make(app: app5)

        readable_space_guids = [space3.guid, space4.guid]
        readable_route_mapping_guids = [route_mapping4.guid, route_mapping5.guid]
        space_actions = %w(space.developer space.manager space.auditor)

        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: space_actions).
          and_return(readable_space_guids)

        expected_route_mapping_guids = org_route_mapping_guids + readable_route_mapping_guids

        expect(permissions.readable_route_mapping_guids).to match_array(expected_route_mapping_guids)
      end
    end

    describe '#can_read_task?' do
      let(:resource_id) { space_id }

      it 'returns true when the user has the task.read permission for the space' do
        allow(perm_client).to receive(:has_permission?).with(action: 'task.read', resource: "#{org_id}/*", user_id: user_id, issuer: issuer).and_return(false)
        allow(perm_client).to receive(:has_permission?).with(action: 'task.read', resource: "#{org_id}/#{space_id}", user_id: user_id, issuer: issuer).and_return(true)

        expect(permissions.can_read_task?(org_guid: org_id, space_guid: space_id)).to equal(true)
      end

      it 'returns true when the user has the task.read permission for the org' do
        allow(perm_client).to receive(:has_permission?).with(action: 'task.read', resource: "#{org_id}/*", user_id: user_id, issuer: issuer).and_return(true)
        allow(perm_client).to receive(:has_permission?).with(action: 'task.read', resource: "#{org_id}/#{space_id}", user_id: user_id, issuer: issuer).and_return(false)

        expect(permissions.can_read_task?(org_guid: org_id, space_guid: space_id)).to equal(true)
      end

      it 'returns false otherwise' do
        allow(perm_client).to receive(:has_permission?).with(action: 'task.read', resource: "#{org_id}/*", user_id: user_id, issuer: issuer).and_return(false)
        allow(perm_client).to receive(:has_permission?).with(action: 'task.read', resource: "#{org_id}/#{space_id}", user_id: user_id, issuer: issuer).and_return(false)

        expect(permissions.can_read_task?(org_guid: org_id, space_guid: space_id)).to equal(false)
      end
    end

    describe '#task_readable_space_guids' do
      it 'returns the list of space guids that the user has task.read access for either that space or the containing org' do
        org = VCAP::CloudController::Organization.make(guid: 'org-guid-1')
        VCAP::CloudController::Space.make(guid: 'space-guid-3', organization: org)

        readable_resource_guids = ['org-guid-1/space-guid-1', 'org-guid-1/space-guid-2', 'org-guid-1/*']
        readable_space_guids = ['space-guid-1', 'space-guid-2', 'space-guid-3']

        allow(perm_client).to receive(:list_unique_resource_patterns).and_return([])
        allow(perm_client).to receive(:list_unique_resource_patterns).
          with(user_id: user_id, issuer: issuer, actions: ['task.read']).
          and_return(readable_resource_guids)

        expect(permissions.task_readable_space_guids).to match_array(readable_space_guids)
      end
    end
  end
end
