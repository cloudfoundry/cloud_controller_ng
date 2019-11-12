require 'spec_helper'
require 'actions/role_delete'

module VCAP::CloudController
  RSpec.describe RoleDeleteAction do
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'amelia@cats.com', user_guid: 'gooid') }

    subject { RoleDeleteAction.new(user_audit_info) }

    describe '#delete' do
      shared_examples 'deletion' do |opts|
        it 'deletes the correct role' do
          expect {
            subject.delete(Role.where(guid: role.guid))
          }.to change { Role.count }.by(-1)

          expect { role.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'records an audit event' do
          expect {
            subject.delete(Role.where(guid: role.guid))
          }.to change { Event.count }.by(1)

          event = Event.last
          expect(event.type).to eq(opts[:event_type])
          expect(event.metadata).to eq({ 'request' => {} })
        end
      end

      context 'space auditor' do
        let!(:role) { SpaceAuditor.make }

        it_behaves_like 'deletion', {
          event_type: 'audit.user.space_auditor_remove'
        }
      end

      context 'space manager' do
        let!(:role) { SpaceManager.make }

        it_behaves_like 'deletion', {
          event_type: 'audit.user.space_manager_remove'
        }
      end

      context 'space developer' do
        let!(:role) { SpaceDeveloper.make }

        it_behaves_like 'deletion', {
          event_type: 'audit.user.space_developer_remove'
        }
      end

      context 'org manager' do
        let!(:role) { OrganizationManager.make }

        it_behaves_like 'deletion', {
          event_type: 'audit.user.organization_manager_remove'
        }
      end

      context 'org billing manager' do
        let!(:role) { OrganizationBillingManager.make }

        it_behaves_like 'deletion', {
          event_type: 'audit.user.organization_billing_manager_remove'
        }
      end

      context 'org auditor' do
        let!(:role) { OrganizationAuditor.make }

        it_behaves_like 'deletion', {
          event_type: 'audit.user.organization_auditor_remove'
        }
      end

      context 'org user' do
        let!(:role) { OrganizationUser.make }

        it_behaves_like 'deletion', {
          event_type: 'audit.user.organization_user_remove'
        }
      end
    end
  end
end
