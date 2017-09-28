require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PermSpaceRolesDelete do
    let(:org_delete_action) { spy('org_delete_action') }
    let(:perm_client) { spy(Perm::Client) }
    subject(:perm_space_roles_delete) { PermSpaceRolesDelete.new(perm_client) }

    let!(:org) { Organization.make }
    let(:space) { Space.make(organization: org) }
    let(:user) { User.make }

    describe '#delete' do
      it 'deletes all the org roles for the org' do
        expect(perm_client).to receive(:delete_space_role).with(role: :manager, space_id: space.guid)
        expect(perm_client).to receive(:delete_space_role).with(role: :developer, space_id: space.guid)
        expect(perm_client).to receive(:delete_space_role).with(role: :auditor, space_id: space.guid)

        errs = perm_space_roles_delete.delete(space)
        expect(errs).to be_empty
      end

      it 'returns an error without raising if it fails to delete a role' do
        allow(perm_client).to receive(:delete_space_role).and_raise

        errs = perm_space_roles_delete.delete(space)
        expected_errs = [CloudController::Errors::ApiError.new_from_details('SpaceRolesDeletionFailed', space.name)]

        expect(errs).to eq(expected_errs)
      end
    end
  end
end
