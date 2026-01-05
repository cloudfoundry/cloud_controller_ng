require 'spec_helper'
require 'actions/stack_delete'

module VCAP::CloudController
  RSpec.describe StackDelete do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }

    subject(:stack_delete) { StackDelete.new(user_audit_info) }

    describe '#delete' do
      context 'when the stack exists' do
        let!(:stack) { Stack.make }

        it 'deletes the stack record' do
          expect do
            stack_delete.delete(stack)
          end.to change(Stack, :count).by(-1)
          expect { stack.refresh }.to raise_error(Sequel::Error, 'Record not found')
        end

        it 'creates an audit event' do
          stack_guid = stack.guid
          stack_name = stack.name

          stack_delete.delete(stack)

          expect(VCAP::CloudController::Event.count).to eq(1)
          stack_delete_event = VCAP::CloudController::Event.find(type: 'audit.stack.delete')
          expect(stack_delete_event).to exist
          expect(stack_delete_event.values).to include(
            type: 'audit.stack.delete',
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actee: stack_guid,
            actee_type: 'stack',
            actee_name: stack_name,
            space_guid: '',
            organization_guid: ''
          )
          expect(stack_delete_event.metadata).to eq({})
          expect(stack_delete_event.timestamp).to be
        end

        it 'deletes associated labels' do
          label = StackLabelModel.make(resource_guid: stack.guid, key_name: 'test1', value: 'bommel')
          expect do
            stack_delete.delete(stack)
          end.to change(StackLabelModel, :count).by(-1)
          expect(label).not_to exist
          expect(stack).not_to exist
        end

        it 'deletes associated annotations' do
          annotation = StackAnnotationModel.make(resource_guid: stack.guid, key_name: 'test1', value: 'bommel')
          expect do
            stack_delete.delete(stack)
          end.to change(StackAnnotationModel, :count).by(-1)
          expect(annotation).not_to exist
          expect(stack).not_to exist
        end

        context 'when there are apps associated with the stack' do
          let!(:app) { AppModel.make }

          before do
            stack.apps << app
          end

          it 'does not delete the stack and raises an error' do
            expect do
              stack_delete.delete(stack)
            end.to raise_error(Stack::AppsStillPresentError)
            expect(stack).to exist
          end
        end
      end
    end
  end
end
