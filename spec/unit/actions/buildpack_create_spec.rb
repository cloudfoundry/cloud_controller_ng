require 'spec_helper'
require 'actions/buildpack_create'
require 'messages/buildpack_create_message'

module VCAP::CloudController
  RSpec.describe BuildpackCreate do
    describe 'create' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_name) { 'user-name' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email, user_name: user_name) }

      let!(:buildpack1) { Buildpack.create(name: 'take-up-position-1', position: 1) }
      let!(:buildpack2) { Buildpack.create(name: 'take-up-position-2', position: 2) }
      let!(:buildpack3) { Buildpack.create(name: 'take-up-position-3', position: 3) }

      before do
        Stack.create(name: 'the-stack')
      end

      context 'when position is not provided' do
        it 'creates a buildpack with a default position of 1' do
          message = BuildpackCreateMessage.new(
            name: 'the-name',
            stack: 'the-stack',
            enabled: false,
            locked: true,
            lifecycle: Lifecycles::BUILDPACK
          )
          buildpack = BuildpackCreate.new(user_audit_info).create(message)

          expect(buildpack.name).to eq('the-name')
          expect(buildpack.stack).to eq('the-stack')
          expect(buildpack.position).to eq(1)
          expect(buildpack.enabled).to be(false)
          expect(buildpack.locked).to be(true)
          expect(buildpack.lifecycle).to eq(Lifecycles::BUILDPACK)
        end

        it 'creates an audit event' do
          message = BuildpackCreateMessage.new(
            name: 'the-name',
            stack: 'the-stack',
            enabled: false,
            locked: true
          )
          buildpack = BuildpackCreate.new(user_audit_info).create(message)

          event = VCAP::CloudController::Event.last

          expect(event.values).to include(
            type: 'audit.buildpack.create',
            actee: buildpack.guid,
            actee_type: 'buildpack',
            actee_name: buildpack.name,
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

      context 'when metadata is provided' do
        it 'creates a buildpack with metadata' do
          message = BuildpackCreateMessage.new(
            name: 'the-name',
            stack: 'the-stack',
            enabled: false,
            locked: true,
            metadata: {
              labels: {
                fruit: 'passionfruit'
              },
              annotations: {
                potato: 'adora'
              }
            }
          )
          buildpack = BuildpackCreate.new(user_audit_info).create(message)

          expect(buildpack.name).to eq('the-name')
          expect(buildpack.stack).to eq('the-stack')
          expect(buildpack.position).to eq(1)
          expect(buildpack.enabled).to be(false)
          expect(buildpack.locked).to be(true)
          expect(buildpack.labels[0].key_name).to eq('fruit')
          expect(buildpack.annotations[0].value).to eq('adora')
        end
      end

      context 'when position is provided' do
        context 'when position is between 1 and number of buildpacks' do
          it 'creates a buildpack at the specified position and shifts subsequent buildpacks position' do
            message = BuildpackCreateMessage.new(
              name: 'the-name',
              position: 2
            )
            buildpack = BuildpackCreate.new(user_audit_info).create(message)

            expect(buildpack.position).to eq(2)
            expect(buildpack1.reload.position).to eq(1)
            expect(buildpack2.reload.position).to eq(3)
            expect(buildpack3.reload.position).to eq(4)
          end
        end

        context 'when position is greater than number of buildpacks' do
          it 'creates a buildpack with a position just after the greatest position' do
            message = BuildpackCreateMessage.new(
              name: 'the-name',
              position: 42
            )
            buildpack = BuildpackCreate.new(user_audit_info).create(message)

            expect(buildpack.position).to eq(4)
          end
        end
      end

      context 'when enabled is not provided' do
        it 'creates a buildpack with enabled set to true' do
          message = BuildpackCreateMessage.new(
            name: 'the-name',
            stack: 'the-stack',
            locked: true
          )
          buildpack = BuildpackCreate.new(user_audit_info).create(message)

          expect(buildpack.enabled).to be(true)
        end
      end

      context 'when locked is not provided' do
        it 'creates a buildpack with locked set to true' do
          message = BuildpackCreateMessage.new(
            name: 'the-name',
            stack: 'the-stack',
            enabled: true
          )
          buildpack = BuildpackCreate.new(user_audit_info).create(message)

          expect(buildpack.locked).to be(false)
        end
      end

      context 'when lifecycle is provided' do
        it 'creates a buildpack with locked set to true' do
          message = BuildpackCreateMessage.new(
            name: 'the-name',
            stack: 'the-stack',
            lifecycle: Lifecycles::CNB
          )
          buildpack = BuildpackCreate.new(user_audit_info).create(message)

          expect(buildpack.lifecycle).to eq(Lifecycles::CNB)
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(Buildpack).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = BuildpackCreateMessage.new(name: 'foobar')
          expect do
            BuildpackCreate.new(user_audit_info).create(message)
          end.to raise_error(BuildpackCreate::Error, 'blork is busted')
        end
      end

      context 'when the associated stack does not exist' do
        it 'raises a human-friendly error' do
          message = BuildpackCreateMessage.new(name: 'the-name', stack: 'does-not-exist')

          expect do
            BuildpackCreate.new(user_audit_info).create(message)
          end.to raise_error(BuildpackCreate::Error, "Stack 'does-not-exist' does not exist")
        end
      end

      context 'when there is a uniqueness error' do
        let(:name) { 'the-name' }

        context 'and stack is nil' do
          before do
            Buildpack.create(name: name, stack: nil)
          end

          it 'raises a human-friendly error' do
            message = BuildpackCreateMessage.new(name:)
            expect do
              BuildpackCreate.new(user_audit_info).create(message)
            end.to raise_error(BuildpackCreate::Error, "Buildpack with name 'the-name' and an unassigned stack already exists")
          end
        end

        context 'and stack is present' do
          before do
            Buildpack.create(name: name, stack: 'the-stack')
          end

          it 'raises a human-friendly error' do
            message = BuildpackCreateMessage.new(name: name, stack: 'the-stack')
            expect do
              BuildpackCreate.new(user_audit_info).create(message)
            end.to raise_error(BuildpackCreate::Error, "Buildpack with name 'the-name', stack 'the-stack' and lifecycle 'buildpack' already exists")
          end
        end
      end
    end
  end
end
