require 'spec_helper'
require 'actions/buildpack_update'
require 'messages/buildpack_update_message'

module VCAP::CloudController
  RSpec.describe BuildpackUpdate do
    describe 'update' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_name) { 'user-name' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email, user_name: user_name) }

      let!(:buildpack1) { Buildpack.make(position: 1) }
      let!(:buildpack2) { Buildpack.make(position: 2) }
      let!(:buildpack3) { Buildpack.make(position: 3) }

      context 'when position is provided' do
        context 'when position is between 1 and number of buildpacks' do
          it 'updates a buildpack at the specified position and shifts subsequent buildpacks position' do
            message = BuildpackUpdateMessage.new(
              position: 2,
              name: 'new-name'
            )
            BuildpackUpdate.new(user_audit_info).update(buildpack1, message)

            expect(buildpack1.reload.position).to eq(2)
            expect(buildpack1.name).to eq('new-name')
            expect(buildpack2.reload.position).to eq(1)
            expect(buildpack3.reload.position).to eq(3)
          end
        end

        it 'updates position transactionally' do
          message = BuildpackUpdateMessage.new(
            position: 2,
            stack: 'invalid-stack'
          )
          expect { BuildpackUpdate.new(user_audit_info).update(buildpack1, message) }.to raise_error(BuildpackUpdate::Error)

          expect(buildpack1.reload.position).to eq(1)
        end
      end

      context 'when enabled is changed' do
        it 'updates the buildpack enabled field' do
          message = BuildpackUpdateMessage.new(
            enabled: false
          )
          buildpack = BuildpackUpdate.new(user_audit_info).update(buildpack1, message)

          expect(buildpack.enabled).to be(false)
        end

        it 'creates an audit event' do
          message = BuildpackUpdateMessage.new(
            enabled: false
          )
          BuildpackUpdate.new(user_audit_info).update(buildpack1, message)

          event = VCAP::CloudController::Event.last

          expect(event.values).to include(
            type: 'audit.buildpack.update',
            actee: buildpack1.guid,
            actee_type: 'buildpack',
            actee_name: buildpack1.name,
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actor_username: user_audit_info.user_name,
            space_guid: '',
            organization_guid: ''
          )
          expect(event.metadata).to eq({ 'request' => message.audit_hash })
          expect(event.timestamp).to be
        end
      end

      context 'when locked is not provided' do
        it 'updates a buildpack with locked set to true' do
          message = BuildpackUpdateMessage.new(
            locked: true
          )
          buildpack = BuildpackUpdate.new(user_audit_info).update(buildpack1, message)

          expect(buildpack.locked).to be(true)
        end
      end

      context 'when name is changed' do
        it 'updates the buildpack name field' do
          message = BuildpackUpdateMessage.new(
            name: 'new-name'
          )
          buildpack = BuildpackUpdate.new(user_audit_info).update(buildpack1, message)

          expect(buildpack.name).to eq('new-name')
        end
      end

      context 'when metadata is changed' do
        it 'updates metadata' do
          message = BuildpackUpdateMessage.new(
            metadata: {
              labels: {
                fruit: 'passionfruit'
              },
              annotations: {
                potato: 'adora'
              }
            }
          )
          buildpack = BuildpackUpdate.new(user_audit_info).update(buildpack1, message)

          expect(buildpack.labels[0].key_name).to eq('fruit')
          expect(buildpack.annotations[0].value).to eq('adora')
        end
      end

      context 'validation errors' do
        context 'when the associated stack does not exist' do
          it 'raises a human-friendly error' do
            message = BuildpackUpdateMessage.new(stack: 'does-not-exist')

            expect do
              BuildpackUpdate.new(user_audit_info).update(buildpack1, message)
            end.to raise_error(BuildpackUpdate::Error, "Stack 'does-not-exist' does not exist")
          end
        end

        context 'when stacks are nil' do
          let(:buildpack1) { Buildpack.make(stack: nil) }
          let(:buildpack2) { Buildpack.make(stack: nil) }

          it 'raises a human-friendly error' do
            message = BuildpackUpdateMessage.new(name: buildpack1.name)
            expect do
              BuildpackUpdate.new(user_audit_info).update(buildpack2, message)
            end.to raise_error(BuildpackUpdate::Error, "Buildpack with name '#{buildpack1.name}' and an unassigned stack already exists")
          end
        end

        context 'when stack is being changed' do
          it 'raises a human-friendly error' do
            message = BuildpackUpdateMessage.new(stack: nil)
            expect do
              BuildpackUpdate.new(user_audit_info).update(buildpack1, message)
            end.to raise_error(BuildpackUpdate::Error, 'Buildpack stack cannot be changed')
          end
        end

        it 'raises a human-friendly error when name, stack and lifecycle conflict' do
          expect(buildpack1.stack).to eq buildpack2.stack
          message = BuildpackUpdateMessage.new(name: buildpack1.name)

          expect do
            BuildpackUpdate.new(user_audit_info).update(buildpack2, message)
          end.to raise_error(BuildpackUpdate::Error, "Buildpack with name '#{buildpack1.name}', stack '#{buildpack1.stack}' and lifecycle '#{buildpack1.lifecycle}' already exists")
        end

        it 're-raises when there is an unknown error' do
          message = BuildpackUpdateMessage.new({})
          buildpack1.errors.add(:foo, 'unknown error')
          allow(buildpack1).to receive(:save).and_raise(Sequel::ValidationFailed.new(buildpack1))

          expect do
            BuildpackUpdate.new(user_audit_info).update(buildpack1, message)
          end.to raise_error(BuildpackUpdate::Error, /unknown error/)
        end
      end
    end
  end
end
