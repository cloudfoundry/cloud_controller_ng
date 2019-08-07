require 'spec_helper'
require 'actions/space_update'

module VCAP::CloudController
  RSpec.describe SpaceUpdate do
    describe 'update' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(name: 'old-space-name', organization: org) }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      context 'when a name and label are requested' do
        let(:message) do
          VCAP::CloudController::SpaceUpdateMessage.new({
           name: 'new-space-name',
           metadata: {
              labels: {
                freaky: 'wednesday',
              },
            },
                                                               }
          )
        end

        it 'updates a space' do
          updated_space = SpaceUpdate.new(user_audit_info).update(space, message)
          expect(updated_space.reload.name).to eq 'new-space-name'
        end

        it 'updates metadata' do
          updated_space = SpaceUpdate.new(user_audit_info).update(space, message)
          expect(updated_space.reload.labels.first.key_name).to eq 'freaky'
          expect(updated_space.reload.labels.first.value).to eq 'wednesday'
        end

        it 'creates an audit event' do
          SpaceUpdate.new(user_audit_info).update(space, message)
          expect(VCAP::CloudController::Event.count).to eq(1)
          event = VCAP::CloudController::Event.first
          expect(event.values).to include(
            type: 'audit.space.update',
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actor_username: user_audit_info.user_name,
            actee: space.guid,
            actee_type: 'space',
            actee_name: 'new-space-name',
            space_guid: space.guid,
            organization_guid: space.organization.guid,
          )
          expect(event.metadata).to eq({ 'request' => message.audit_hash })
          expect(event.timestamp).to be
        end

        context 'when model validation fails' do
          it 'errors' do
            errors = Sequel::Model::Errors.new
            errors.add(:blork, 'is busted')
            expect(space).to receive(:save).
              and_raise(Sequel::ValidationFailed.new(errors))

            expect {
              SpaceUpdate.new(user_audit_info).update(space, message)
            }.to raise_error(SpaceUpdate::Error, 'blork is busted')
          end
        end

        context 'when the space name is not unique' do
          it 'errors usefully' do
            VCAP::CloudController::Space.make(name: 'new-space-name', organization: org)

            expect {
              SpaceUpdate.new(user_audit_info).update(space, message)
            }.to raise_error(SpaceUpdate::Error, "Organization '#{org.name}' already contains a space with name '#{message.name}'.")
          end
        end
      end

      context 'when nothing is requested' do
        let(:message) do
          VCAP::CloudController::SpaceUpdateMessage.new({})
        end

        it 'does not change the space name' do
          updated_space = SpaceUpdate.new(user_audit_info).update(space, message)
          expect(updated_space.reload.name).to eq 'old-space-name'
        end
      end
    end
  end
end
