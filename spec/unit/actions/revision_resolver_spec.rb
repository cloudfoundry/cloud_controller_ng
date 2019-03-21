require 'spec_helper'
require 'actions/revision_resolver'

module VCAP::CloudController
  RSpec.describe RevisionResolver do
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

    describe '.update_app_revision' do
      context 'when revisions are disabled' do
        before do
          app.update(revisions_enabled: false)
        end

        it 'return nil' do
          expect {
            expect(RevisionResolver.update_app_revision(app, user_audit_info)).to be_nil
          }.not_to change { RevisionModel.count }
        end
      end

      context 'when it is the initial revision' do
        it 'creates a revision from the app values with the appropriate description' do
          expect {
            RevisionResolver.update_app_revision(app, user_audit_info)
          }.to change { RevisionModel.where(app: app).count }.by(1)

          revision = RevisionModel.last
          expect(revision.app).to eq(app)
          expect(revision.droplet_guid).to eq(app.droplet.guid)
          expect(revision.environment_variables).to eq(app.environment_variables)
          expect(revision.commands_by_process_type).to eq(app.commands_by_process_type)
          expect(revision.description).to eq('Initial revision.')
        end
      end

      context 'when the latest revision is out of date' do
        it 'creates a revision from the app values with the appropriate description' do
          existing_revision = RevisionModel.make(
            app: app,
            droplet: app.droplet,
            environment_variables: { 'foo' => 'bar' },
          )
          RevisionProcessCommandModel.make(
            revision_guid: existing_revision.guid,
            process_type: 'web',
            process_command: 'bundle exec earlier_app',
          )

          expect {
            RevisionResolver.update_app_revision(app, user_audit_info)
          }.to change { RevisionModel.where(app: app).count }.by(1)

          revision = RevisionModel.last
          expect(revision.app).to eq(app)
          expect(revision.droplet_guid).to eq(app.droplet.guid)
          expect(revision.environment_variables).to eq(app.environment_variables)
          expect(revision.commands_by_process_type).to eq(app.commands_by_process_type)
          expect(revision.description).to eq("Custom start command updated for 'web' process. New environment variables deployed.")
        end
      end

      context 'when the latest revisions is up to date' do
        it 'returns the latest_revision' do
          existing_revision = RevisionModel.make(
            :revision,
            app: app,
            droplet: app.droplet,
            environment_variables: app.environment_variables,
          )
          RevisionProcessCommandModel.make(
            revision_guid: existing_revision.guid,
            process_type: 'web',
            process_command: 'run my app',
          )

          revision = nil
          expect {
            revision = RevisionResolver.update_app_revision(app, user_audit_info)
          }.to change { RevisionModel.where(app: app).count }.by(0)

          expect(revision).to eq(app.latest_revision)
        end
      end
    end

    describe '.rollback_app_revision' do
      let(:revision) do
        RevisionModel.make(
          version: 2,
          droplet: droplet,
          app: app,
          environment_variables: { 'BISH': 'BASH', 'FOO': 'BAR' }
        )
      end
      let!(:revision_web_process_command) do
        RevisionProcessCommandModel.make(
          revision: revision,
          process_type: ProcessTypes::WEB,
          process_command: 'foo rackup stuff',
        )
      end

      let!(:revision_worker_process_command) do
        RevisionProcessCommandModel.make(
          revision: revision,
          process_type: 'worker',
          process_command: 'on the railroad',
        )
      end

      context 'when revisions are disabled' do
        before do
          app.update(revisions_enabled: false)
        end

        it 'return nil' do
          expect {
            expect(RevisionResolver.rollback_app_revision(revision, user_audit_info)).to be_nil
          }.not_to change { RevisionModel.count }
        end
      end

      it 'creates a new rollback revision' do
        rollback_revision = RevisionResolver.rollback_app_revision(revision, user_audit_info)

        expect(rollback_revision.description).to eq('Rolled back to revision 2.')
        expect(rollback_revision.app).to eq(revision.app)
        expect(rollback_revision.droplet).to eq(revision.droplet)
        expect(rollback_revision.environment_variables).to eq(revision.environment_variables)
        expect(rollback_revision.commands_by_process_type).to eq(revision.commands_by_process_type)
        expect(rollback_revision.process_commands).not_to eq(revision.process_commands)
      end

      it 'does not copy metadata to the new rollback revision' do
        RevisionAnnotationModel.make(revision: revision, key: 'foo', value: 'bar')
        RevisionLabelModel.make(revision: revision, key_name: 'baz', value: 'qux')

        rollback_revision = RevisionResolver.rollback_app_revision(revision, user_audit_info)

        expect(rollback_revision.annotations).to be_empty
        expect(rollback_revision.labels).to be_empty
      end
    end
  end
end
