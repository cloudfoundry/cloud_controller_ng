require 'spec_helper'
require 'actions/revision_create'

module VCAP::CloudController
  RSpec.describe RevisionCreate do
    let(:droplet) do
      DropletModel.make(
        app: app,
        process_types: {
          'web' => 'droplet_web_command',
          'worker' => 'droplet_worker_command',
        })
    end
    let(:app) { AppModel.make(revisions_enabled: true) }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: '456', user_email: 'mona@example.com', user_name: 'mona') }
    let(:sidecar) { SidecarModel.make(app: app, command: 'sleep infinity', name: 'sleepy', memory: 12) }
    let!(:sidecar_process_type) { SidecarProcessTypeModel.make(sidecar: sidecar, type: 'web') }

    before do
      app.update(droplet: droplet)
    end

    describe '.create' do
      it 'creates a revision for the app' do
        expect {
          RevisionCreate.create(
            app: app,
            droplet_guid: app.droplet_guid,
            environment_variables: { 'key' => 'value' },
            description: 'foo sorta',
            commands_by_process_type: { 'web' => 'run my app', 'worker' => nil },
            user_audit_info: user_audit_info,
          )
        }.to change { RevisionModel.where(app: app).count }.by(1)

        revision = RevisionModel.last
        expect(revision.droplet_guid).to eq(droplet.guid)
        expect(revision.version).to eq(1)
        expect(revision.environment_variables).to eq({ 'key' => 'value' })
        expect(revision.commands_by_process_type).to eq({
          'web' => 'run my app',
          'worker' => nil,
        })
        expect(revision.description).to eq('foo sorta')
        expect(revision.sidecars.first.name).to eq('sleepy')
        expect(revision.sidecars.first.command).to eq('sleep infinity')
        expect(revision.sidecars.first.memory).to eq(12)
        expect(revision.sidecars.first.revision_sidecar_process_types.first.type).to eq('web')
      end

      it 'records an audit event for the revision' do
        revision = nil
        expect {
          revision = RevisionCreate.create(
            app: app,
            droplet_guid: app.droplet_guid,
            environment_variables: { 'key' => 'value' },
            description: 'foo sorta',
            commands_by_process_type: { 'web' => 'run my app' },
            user_audit_info: user_audit_info,
          )
        }.to change { Event.count }.by(1)

        event = VCAP::CloudController::Event.find(type: 'audit.app.revision.create')
        expect(event).not_to be_nil
        expect(event.actor).to eq('456')
        expect(event.actor_type).to eq('user')
        expect(event.actor_name).to eq('mona@example.com')
        expect(event.actor_username).to eq('mona')
        expect(event.actee).to eq(app.guid)
        expect(event.actee_type).to eq('app')
        expect(event.actee_name).to eq(app.name)
        expect(event.timestamp).to be
        expect(event.space_guid).to eq(app.space_guid)
        expect(event.organization_guid).to eq(app.space.organization.guid)
        expect(event.metadata).to eq({
          'revision_guid' => revision.guid,
          'revision_version' => revision.version,
        })
      end

      context 'when there is no user_audit_info for the revision' do
        let(:user_audit_info) { nil }
        it 'should not create a user audit event' do
          RevisionCreate.create(
            app: app,
            droplet_guid: app.droplet_guid,
            environment_variables: { 'key' => 'value' },
            description: 'foo sorta',
            commands_by_process_type: { 'web' => 'run my app' },
            user_audit_info: user_audit_info,
          )
          event = VCAP::CloudController::Event.find(type: 'audit.app.revision.create')
          expect(event).to be_nil
        end
      end

      context 'when there are multiple revisions for an app' do
        it 'increments the version by 1' do
          RevisionModel.make(app: app, version: 1, created_at: 4.days.ago)

          expect {
            RevisionCreate.create(
              app: app,
              droplet_guid: app.droplet_guid,
              environment_variables: { 'key' => 'value' },
              description: 'foo sorta',
              commands_by_process_type: { 'web' => 'run my app' },
              user_audit_info: user_audit_info,
            )
          }.to change { RevisionModel.where(app: app).count }.by(1)

          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([1, 2])
        end

        it 'rolls over to version 1 when we pass version 9999' do
          RevisionModel.make(app: app, version: 1, created_at: 5.days.ago)
          RevisionModel.make(app: app, version: 2, created_at: 4.days.ago)
          # ...
          RevisionModel.make(app: app, version: 9998, created_at: 3.days.ago)
          RevisionModel.make(app: app, version: 9999, created_at: 2.days.ago)

          RevisionCreate.create(
            app: app,
            droplet_guid: app.droplet_guid,
            environment_variables: { 'key' => 'value' },
            description: 'foo sorta',
            commands_by_process_type: { 'web' => 'run my app' },
            user_audit_info: user_audit_info,
          )
          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([2, 9998, 9999, 1])
        end

        it 'replaces any existing revisions after rolling over' do
          RevisionModel.make(app: app, version: 2, created_at: 4.days.ago)
          # ...
          RevisionModel.make(app: app, version: 9998, created_at: 3.days.ago)
          RevisionModel.make(app: app, version: 9999, created_at: 2.days.ago)
          RevisionModel.make(app: app, version: 1, created_at: 1.days.ago)

          RevisionCreate.create(
            app: app,
            droplet_guid: app.droplet_guid,
            environment_variables: { 'key' => 'value' },
            description: 'foo sorta',
            commands_by_process_type: { 'web' => 'run my app' },
            user_audit_info: user_audit_info,
          )
          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([9998, 9999, 1, 2])
        end
      end
    end
  end
end
