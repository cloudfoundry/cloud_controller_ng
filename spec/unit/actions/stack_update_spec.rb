require 'spec_helper'
require 'actions/stack_update'

module VCAP::CloudController
  RSpec.describe StackUpdate do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }

    subject(:stack_update) { StackUpdate.new(user_audit_info) }

    describe '#update' do
      let(:body) do
        {
          metadata: {
            labels: {
              freaky: 'wednesday'
            },
            annotations: {
              tokyo: 'grapes'
            }
          }
        }
      end
      let(:stack) { Stack.make }
      let(:message) { StackUpdateMessage.new(body) }

      it 'updates the stack metadata' do
        expect(message).to be_valid
        stack_update.update(stack, message)

        stack.reload
        expect(stack).to have_labels({ key_name: 'freaky', value: 'wednesday' })
        expect(stack).to have_annotations({ key_name: 'tokyo', value: 'grapes' })
      end

      it 'creates an audit event' do
        stack_update.update(stack, message)

        expect(VCAP::CloudController::Event.count).to eq(1)
        stack_update_event = VCAP::CloudController::Event.find(type: 'audit.stack.update')
        expect(stack_update_event).to exist
        expect(stack_update_event.values).to include(
          type: 'audit.stack.update',
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actee: stack.guid,
          actee_type: 'stack',
          actee_name: stack.name,
          space_guid: '',
          organization_guid: ''
        )
        expect(stack_update_event.metadata).to eq({ 'request' => message.audit_hash })
        expect(stack_update_event.timestamp).to be
      end
    end
  end
end
