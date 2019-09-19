require 'spec_helper'
require 'actions/organization_update'

module VCAP::CloudController
  RSpec.describe OrganizationUpdate do
    describe 'update' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
      subject(:org_update) { OrganizationUpdate.new(user_audit_info) }
      let(:org) { VCAP::CloudController::Organization.make(name: 'old-org-name') }

      context 'when a name and label are requested' do
        let(:message) do
          VCAP::CloudController::OrganizationUpdateMessage.new({
            name: 'new-org-name',
            metadata: {
              labels: {
                freaky: 'wednesday',
              },
              annotations: {
                hello: 'there'
              }
            },
          })
        end

        it 'updates a organization' do
          updated_org = org_update.update(org, message)
          expect(updated_org.reload.name).to eq 'new-org-name'
        end

        it 'updates metadata' do
          updated_org = org_update.update(org, message)
          updated_org.reload
          expect(updated_org.labels.first.key_name).to eq 'freaky'
          expect(updated_org.labels.first.value).to eq 'wednesday'
          expect(updated_org.annotations.first.key).to eq 'hello'
          expect(updated_org.annotations.first.value).to eq 'there'
        end

        it 'creates an audit event' do
          updated_org = org_update.update(org, message)
          expect(VCAP::CloudController::Event.count).to eq(1)
          event = VCAP::CloudController::Event.first
          expect(event.values).to include(
            type: 'audit.organization.update',
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actor_username: user_audit_info.user_name,
            actee: updated_org.guid,
            actee_type: 'organization',
            actee_name: 'new-org-name',
            organization_guid: updated_org.guid
          )
          expect(event.metadata).to eq({ 'request' => message.audit_hash })
          expect(event.timestamp).to be
        end

        context 'when model validation fails' do
          it 'errors' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(org).to receive(:save).
              and_raise(Sequel::ValidationFailed.new(errors))

            expect {
              org_update.update(org, message)
            }.to raise_error(OrganizationUpdate::Error, 'blork is busted')
          end
        end

        context 'when the org name is not unique' do
          it 'errors usefully' do
            VCAP::CloudController::Organization.make(name: 'new-org-name')

            expect {
              org_update.update(org, message)
            }.to raise_error(OrganizationUpdate::Error, "Organization name 'new-org-name' is already taken.")
          end
        end
      end

      context 'when suspended is requested' do
        let(:message) do
          VCAP::CloudController::OrganizationUpdateMessage.new({
            name: 'new-org-name',
            suspended: true
          })
        end

        it 'updates a organization' do
          updated_org = org_update.update(org, message)
          expect(updated_org.reload.name).to eq 'new-org-name'
        end

        it 'updates suspended' do
          updated_org = org_update.update(org, message)
          updated_org.reload
          expect(updated_org).to be_suspended
        end

        context 'when model validation fails' do
          it 'errors' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(org).to receive(:save).
              and_raise(Sequel::ValidationFailed.new(errors))

            expect {
              org_update.update(org, message)
            }.to raise_error(OrganizationUpdate::Error, 'blork is busted')
          end
        end

        context 'when the org name is not unique' do
          it 'errors usefully' do
            VCAP::CloudController::Organization.make(name: 'new-org-name')

            expect {
              org_update.update(org, message)
            }.to raise_error(OrganizationUpdate::Error, "Organization name 'new-org-name' is already taken.")
          end
        end
      end

      context 'when nothing is requested' do
        let(:message) do
          VCAP::CloudController::OrganizationUpdateMessage.new({})
        end

        it 'does not change the organization name' do
          updated_org = org_update.update(org, message)
          expect(updated_org.reload.name).to eq 'old-org-name'
        end

        it 'does not change labels' do
          updated_org = org_update.update(org, message)
          expect(updated_org.reload.labels).to be_empty
        end
      end
    end
  end
end
