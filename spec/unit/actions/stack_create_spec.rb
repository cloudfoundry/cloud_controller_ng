require 'spec_helper'
require 'actions/stack_create'
require 'messages/stack_create_message'

module VCAP::CloudController
  RSpec.describe StackCreate do
    describe 'create' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }

      subject(:stack_create) { StackCreate.new(user_audit_info) }

      it 'creates a stack' do
        message = VCAP::CloudController::StackCreateMessage.new(
          name: 'the-name',
          description: 'the-description',
          state: 'ACTIVE',
          metadata: {
            labels: {
              release: 'stable',
              'seriouseats.com/potato' => 'mashed'
            },
            annotations: {
              tomorrow: 'land',
              backstreet: 'boys'
            }
          }
        )
        stack = stack_create.create(message)

        expect(stack.name).to eq('the-name')
        expect(stack.description).to eq('the-description')

        expect(stack).to have_labels(
          { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' },
          { prefix: nil, key_name: 'release', value: 'stable' }
        )
        expect(stack).to have_annotations(
          { key_name: 'tomorrow', value: 'land' },
          { key_name: 'backstreet', value: 'boys' }
        )
      end

      it 'creates an audit event' do
        message = VCAP::CloudController::StackCreateMessage.new(
          name: 'my-stack',
          description: 'my-description'
        )
        created_stack = stack_create.create(message)

        expect(VCAP::CloudController::Event.count).to eq(1)
        stack_create_event = VCAP::CloudController::Event.find(type: 'audit.stack.create')
        expect(stack_create_event).to exist
        expect(stack_create_event.values).to include(
          type: 'audit.stack.create',
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actee: created_stack.guid,
          actee_type: 'stack',
          actee_name: 'my-stack',
          space_guid: '',
          organization_guid: ''
        )
        expect(stack_create_event.metadata).to eq({ 'request' => message.audit_hash })
        expect(stack_create_event.timestamp).to be
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::Stack).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::StackCreateMessage.new(name: 'foobar')
          expect do
            stack_create.create(message)
          end.to raise_error(StackCreate::Error, 'blork is busted')
        end
      end

      context 'when it is a uniqueness error' do
        let(:name) { 'Olsen' }

        before do
          VCAP::CloudController::Stack.create(name:)
        end

        it 'raises a human-friendly error' do
          message = VCAP::CloudController::StackCreateMessage.new(name:)
          expect do
            stack_create.create(message)
          end.to raise_error(StackCreate::Error, 'Name must be unique')
        end
      end

      context 'when creating stack with the same name concurrently' do
        let(:name) { 'Gaby' }

        it 'ensures one creation is successful and the other fails due to name conflict' do
          message = VCAP::CloudController::StackCreateMessage.new(name: name, state: 'ACTIVE')
          # First request, should succeed
          expect do
            stack_create.create(message)
          end.not_to raise_error

          # Mock the validation for the second request to simulate the race condition and trigger a unique constraint violation
          allow_any_instance_of(Stack).to receive(:validate).and_return(true)

          # Second request, should fail with correct error
          expect do
            stack_create.create(message)
          end.to raise_error(StackCreate::Error, 'Name must be unique')
        end
      end
    end
  end
end
