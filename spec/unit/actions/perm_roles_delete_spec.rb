require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PermRolesDelete do
    let(:org_delete_action) { spy('org_delete_action') }
    let(:perm_client) { spy('perm_client') }
    let(:role_prefixes) { ['foo-bar', 'bar-baz'] }

    let!(:org_1) { Organization.make }
    let!(:org_2) { Organization.make }

    let!(:org_dataset) { Organization.where(guid: [org_1.guid, org_2.guid]) }
    let(:user) { User.make }

    describe '#delete' do
      context 'when not enabled' do
        it 'just calls to the underlying action' do
          perm_roles_delete = PermRolesDelete.new(perm_client, false, org_delete_action, role_prefixes)

          expect(perm_client).not_to receive(:delete_role)
          expect(org_delete_action).to receive(:delete).with(org_dataset)

          perm_roles_delete.delete(org_dataset)
        end
      end

      context 'when enabled' do
        it 'uses the client to delete all of the roles made from prefixes and the guid' do
          perm_roles_delete = PermRolesDelete.new(perm_client, true, org_delete_action, role_prefixes)

          expect(perm_client).to receive(:delete_role).with("foo-bar-#{org_1.guid}")
          expect(perm_client).to receive(:delete_role).with("foo-bar-#{org_2.guid}")
          expect(perm_client).to receive(:delete_role).with("bar-baz-#{org_1.guid}")
          expect(perm_client).to receive(:delete_role).with("bar-baz-#{org_2.guid}")
          expect(org_delete_action).to receive(:delete).with(org_dataset)

          perm_roles_delete.delete(org_dataset)
        end
      end
    end
  end
end
