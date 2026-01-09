require 'spec_helper'
require 'actions/space_quota_delete'

module VCAP::CloudController
  RSpec.describe SpaceQuotaDeleteAction do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_name) { 'user-name' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email, user_name: user_name) }

    subject(:space_quota_delete) { SpaceQuotaDeleteAction.new(user_audit_info) }

    describe '#delete' do
      let(:org) { Organization.make }
      let!(:quota) { SpaceQuotaDefinition.make(organization: org) }

      it 'deletes the space quota' do
        expect do
          space_quota_delete.delete([quota])
        end.to change(SpaceQuotaDefinition, :count).by(-1)

        expect { quota.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      it 'creates an audit event' do
        quota_guid = quota.guid
        quota_name = quota.name

        space_quota_delete.delete([quota])

        expect(VCAP::CloudController::Event.count).to eq(1)
        event = VCAP::CloudController::Event.last

        expect(event.values).to include(
          type: 'audit.space_quota.delete',
          actee: quota_guid,
          actee_type: 'space_quota',
          actee_name: quota_name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          space_guid: '',
          organization_guid: org.guid
        )
        expect(event.metadata).to eq({})
        expect(event.timestamp).to be
      end
    end
  end
end
