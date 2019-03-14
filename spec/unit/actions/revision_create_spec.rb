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
    let(:app) { FactoryBot.create(:app, revisions_enabled: true, environment_variables: { 'key' => 'value' }) }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: '456', user_email: 'mona@example.com', user_name: 'mona') }
    let!(:older_web_process) { ProcessModel.make(app: app, type: 'web', command: 'run my app', created_at: 2.minutes.ago) }
    let!(:worker_process) { ProcessModel.make(app: app, type: 'worker') }

    before do
      app.update(droplet: droplet)
    end

    describe '.create' do
      it 'creates a revision for the app' do
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
          FactoryBot.create(:revision, app: app, version: 1, created_at: 5.days.ago)
          FactoryBot.create(:revision, app: app, version: 2, created_at: 4.days.ago)
          # ...
          FactoryBot.create(:revision, app: app, version: 9998, created_at: 3.days.ago)
          FactoryBot.create(:revision, app: app, version: 9999, created_at: 2.days.ago)

          RevisionCreate.create(app, user_audit_info)
          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([2, 9998, 9999, 1])
        end

        it 'replaces any existing revisions after rolling over' do
          FactoryBot.create(:revision, app: app, version: 2, created_at: 4.days.ago)
          # ...
          FactoryBot.create(:revision, app: app, version: 9998, created_at: 3.days.ago)
          FactoryBot.create(:revision, app: app, version: 9999, created_at: 2.days.ago)
          FactoryBot.create(:revision, app: app, version: 1, created_at: 1.days.ago)

          RevisionCreate.create(app, user_audit_info)
          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([9998, 9999, 1, 2])
        end
      end

      describe 'description' do
        before do
          revision = FactoryBot.create(:revision, app: app, droplet_guid: app.droplet.guid, environment_variables: app.environment_variables)
          RevisionProcessCommandModel.make(revision: revision, process_type: older_web_process.type, process_command: older_web_process.command)
          RevisionProcessCommandModel.make(revision: revision, process_type: worker_process.type, process_command: worker_process.command)
        end

        context 'when it is the first revision' do
          before do
            RevisionProcessCommandModel.dataset.destroy
            RevisionModel.dataset.destroy
          end

          it 'adds a first revision description' do
            revision = RevisionCreate.create(app, user_audit_info)
            expect(revision.description).to eq('Initial revision.')
          end
        end

        context 'when there is a new droplet' do
          it 'adds a new droplet description' do
            new_droplet = DropletModel.make(app: app)
            app.update(droplet: new_droplet)

            revision = RevisionCreate.create(app, user_audit_info)
            expect(revision.description).to eq('New droplet deployed.')
          end
        end

        context 'when there are new env vars' do
          it 'adds a new env var description' do
            app.update(environment_variables: { 'key' => 'value2' })

            revision = RevisionCreate.create(app, user_audit_info)
            expect(revision.description).to eq('New environment variables deployed.')
          end
        end

        context 'when custom start commands are added' do
          it 'add new custom start command description' do
            worker_process.update(command: './start-my-worker')

            revision = RevisionCreate.create(app, user_audit_info)
            expect(revision.description).to eq("Custom start command added for 'worker' process.")
          end
        end

        context 'when custom start commands are removed' do
          it 'add removed custom start command description' do
            older_web_process.update(command: nil)

            revision = RevisionCreate.create(app, user_audit_info)
            expect(revision.description).to eq("Custom start command removed for 'web' process.")
          end
        end

        context 'when custom start commands are changed' do
          it 'add changed custom start command description' do
            older_web_process.update(command: '.some-other-web-command')

            revision = RevisionCreate.create(app, user_audit_info)
            expect(revision.description).to eq("Custom start command updated for 'web' process.")
          end
        end

        context 'when process types are added' do
          it 'add changed custom start command description' do
            ProcessModel.make(app: app, type: 'other-type', command: 'run my app', created_at: 2.minutes.ago)

            revision = RevisionCreate.create(app, user_audit_info)
            expect(revision.description).to eq("New process type 'other-type' added.")
          end
        end

        context 'when process types are removed' do
          it 'add changed custom start command description' do
            worker_process.delete

            revision = RevisionCreate.create(app, user_audit_info)
            expect(revision.description).to eq("Process type 'worker' removed.")
          end
        end

        context 'when a revision is rolled back' do
          it 'only shows the rollback reason' do
            revision = RevisionCreate.create(app, user_audit_info, previous_version: 2)
            expect(revision.description).to eq('Rolled back to revision 2')
          end
        end

        context 'when there are multiple reasons' do
          it 'adds descriptions in alphabetical order' do
            new_droplet = DropletModel.make(app: app)
            app.update(droplet: new_droplet)
            app.update(environment_variables: { 'key' => 'value2' })
            older_web_process.update(command: nil)
            ProcessModel.make(app: app, type: 'other-type', command: 'run my app', created_at: 2.minutes.ago)

            revision = RevisionCreate.create(app, user_audit_info)
            expect(revision.description).
              to eq("Custom start command removed for 'web' process. New droplet deployed. New environment variables deployed. New process type 'other-type' added.")
          end
        end
      end
    end
  end
end
