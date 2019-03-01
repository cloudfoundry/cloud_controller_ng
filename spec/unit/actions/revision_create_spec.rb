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
    let(:app) { AppModel.make(revisions_enabled: true, environment_variables: { 'key' => 'value' }) }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: '456', user_email: 'mona@example.com', user_name: 'mona') }
    let!(:older_web_process) { ProcessModel.make(app: app, type: 'web', command: 'run my app', created_at: 2.minutes.ago) }
    let!(:worker_process) { ProcessModel.make(app: app, type: 'worker') }

    describe '.create' do
      it 'creates a revision for the app' do
        app.update(droplet: droplet)
        expect {
          RevisionCreate.create(app, user_audit_info)
        }.to change { RevisionModel.where(app: app).count }.by(1)

        revision = RevisionModel.last
        expect(revision.droplet_guid).to eq(droplet.guid)
        expect(revision.environment_variables).to eq(app.environment_variables)
        expect(revision.commands_by_process_type).to eq({
          'web' => 'run my app',
          'worker' => nil,
        })
      end

      context 'when there are multiple processes of the same type' do
        let!(:newer_web_process) { ProcessModel.make(app: app, type: 'web', command: 'run my newer app!', created_at: 1.minute.ago) }

        it 'saves off the custom start commands for the newer duplicate processes' do
          app.update(droplet: droplet)
          expect {
            RevisionCreate.create(app, user_audit_info)
          }.to change { RevisionModel.where(app: app).count }.by(1)

          revision = RevisionModel.last
          expect(revision.commands_by_process_type).to eq({
            'web' => 'run my newer app!',
            'worker' => nil,
          })
        end
      end

      it 'records an audit event for the revision' do
        revision = nil
        expect {
          revision = RevisionCreate.create(app, user_audit_info)
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

      context 'when there are multiple revisions for an app' do
        it 'increments the version by 1' do
          RevisionCreate.create(app, user_audit_info)
          expect {
            RevisionCreate.create(app, user_audit_info)
          }.to change { RevisionModel.where(app: app).count }.by(1)

          expect(RevisionModel.map(&:version)).to eq([1, 2])
        end

        it 'rolls over to version 1 when we pass version 9999' do
          RevisionModel.make(app: app, version: 1, created_at: 5.days.ago)
          RevisionModel.make(app: app, version: 2, created_at: 4.days.ago)
          # ...
          RevisionModel.make(app: app, version: 9998, created_at: 3.days.ago)
          RevisionModel.make(app: app, version: 9999, created_at: 2.days.ago)

          RevisionCreate.create(app, user_audit_info)
          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([2, 9998, 9999, 1])
        end

        it 'replaces any existing revisions after rolling over' do
          RevisionModel.make(app: app, version: 2, created_at: 4.days.ago)
          # ...
          RevisionModel.make(app: app, version: 9998, created_at: 3.days.ago)
          RevisionModel.make(app: app, version: 9999, created_at: 2.days.ago)
          RevisionModel.make(app: app, version: 1, created_at: 1.days.ago)

          RevisionCreate.create(app, user_audit_info)
          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([9998, 9999, 1, 2])
        end
      end
    end
  end
end
