require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PermOrgRolesDelete do
    let(:org_delete_action) { spy('org_delete_action') }
    let(:perm_client) { spy(Perm::Client) }
    subject(:perm_org_roles_delete) { PermOrgRolesDelete.new(perm_client) }

    let!(:org) { Organization.make }
    let(:user) { User.make }

    describe '#delete' do
      it 'deletes all the org roles for the org' do
        expect(perm_client).to receive(:delete_org_role).with(role: :manager, org_id: org.guid)
        expect(perm_client).to receive(:delete_org_role).with(role: :billing_manager, org_id: org.guid)
        expect(perm_client).to receive(:delete_org_role).with(role: :user, org_id: org.guid)
        expect(perm_client).to receive(:delete_org_role).with(role: :auditor, org_id: org.guid)

        errs = perm_org_roles_delete.delete(org)
        expect(errs).to be_empty
      end

      it 'returns an error without raising if it fails to delete a role' do
        allow(perm_client).to receive(:delete_org_role).and_raise

        errs = perm_org_roles_delete.delete(org)
        expected_errs = [CloudController::Errors::ApiError.new_from_details('OrganizationRolesDeletionFailed', org.name)]

        expect(errs).to eq(expected_errs)
      end
    end
  end
end
