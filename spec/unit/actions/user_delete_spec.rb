require 'spec_helper'
require 'actions/user_delete'

module VCAP::CloudController
  RSpec.describe UserDeleteAction do
    subject(:user_delete) { UserDeleteAction.new }

    describe '#delete' do
      let!(:user) { User.make }

      it 'deletes the user record' do
        expect {
          user_delete.delete([user])
        }.to change { User.count }.by(-1)
        expect { user.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      describe 'recursive deletion' do
        let(:user) { User.make }
        let(:space) { Space.make }
        let(:org) { space.organization }

        describe 'roles' do
          it 'deletes associated space auditor roles' do
            set_current_user_as_role(role: 'space_auditor', org: org, space: space, user: user)
            role = SpaceAuditor.find(user_id: user.id, space_id: space.id)

            expect {
              user_delete.delete([user])
            }.to change { user.audited_spaces.count }.by(-1)

            expect { role.reload }.to raise_error Sequel::NoExistingObject
          end

          it 'deletes associated space developer roles' do
            set_current_user_as_role(role: 'space_developer', org: org, space: space, user: user)
            role = SpaceDeveloper.find(user_id: user.id, space_id: space.id)

            expect {
              user_delete.delete([user])
            }.to change { user.spaces.count }.by(-1)
            expect { role.reload }.to raise_error Sequel::NoExistingObject
          end

          it 'deletes associated space manager roles' do
            set_current_user_as_role(role: 'space_manager', org: org, space: space, user: user)
            role = SpaceManager.find(user_id: user.id, space_id: space.id)

            expect {
              user_delete.delete([user])
            }.to change { user.managed_spaces.count }.by(-1)

            expect { role.reload }.to raise_error Sequel::NoExistingObject
          end

          it 'deletes associated org user roles' do
            set_current_user_as_role(role: 'org_user', org: org, user: user)
            role = OrganizationUser.find(user_id: user.id, organization_id: org.id)

            expect {
              user_delete.delete([user])
            }.to change { user.organizations.count }.by(-1)

            expect { role.reload }.to raise_error Sequel::NoExistingObject
          end

          it 'deletes associated org auditor roles' do
            set_current_user_as_role(role: 'org_auditor', org: org, user: user)
            role = OrganizationAuditor.find(user_id: user.id, organization_id: org.id)

            expect {
              user_delete.delete([user])
            }.to change { user.audited_organizations.count }.by(-1)

            expect { role.reload }.to raise_error Sequel::NoExistingObject
          end

          it 'deletes associated org manager roles' do
            set_current_user_as_role(role: 'org_manager', org: org, user: user)
            role = OrganizationManager.find(user_id: user.id, organization_id: org.id)

            expect {
              user_delete.delete([user])
            }.to change { user.managed_organizations.count }.by(-1)

            expect { role.reload }.to raise_error Sequel::NoExistingObject
          end

          it 'deletes associated org billing manager roles' do
            set_current_user_as_role(role: 'org_billing_manager', org: org, user: user)
            role = OrganizationBillingManager.find(user_id: user.id, organization_id: org.id)

            expect {
              user_delete.delete([user])
            }.to change { user.billing_managed_organizations.count }.by(-1)

            expect { role.reload }.to raise_error Sequel::NoExistingObject
          end
        end
      end
    end
  end
end
