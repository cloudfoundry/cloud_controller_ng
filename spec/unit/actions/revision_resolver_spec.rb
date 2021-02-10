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
    let(:app) { AppModel.make(revisions_enabled: true, environment_variables: { 'key' => 'value' }) }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: '456', user_email: 'mona@example.com', user_name: 'mona') }
    let!(:older_web_process) { ProcessModel.make(app: app, type: 'web', created_at: 2.minutes.ago) }
    let!(:worker_process) { ProcessModel.make(app: app, type: 'worker') }

    before do
      app.update(droplet: droplet)
    end

    describe '.update_app_revision' do
      context 'when revisions are disabled' do
        before do
          app.update(revisions_enabled: false)
        end

        it 'returns nil' do
          expect {
            expect(RevisionResolver.update_app_revision(app, user_audit_info)).to be_nil
          }.not_to change { RevisionModel.count }
        end
      end

      context 'when app has no droplet' do
        it 'returns nil' do
          app.update(droplet_guid: nil)
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
          RevisionModel.make(:custom_web_command,
            app: app,
            droplet: app.droplet,
            environment_variables: { 'foo' => 'bar' },
          )

          expect {
            RevisionResolver.update_app_revision(app, user_audit_info)
          }.to change { RevisionModel.where(app: app).count }.by(1)

          revision = RevisionModel.last
          expect(revision.app).to eq(app)
          expect(revision.droplet_guid).to eq(app.droplet.guid)
          expect(revision.environment_variables).to eq(app.environment_variables)
          expect(revision.commands_by_process_type).to eq(app.commands_by_process_type)
          expect(revision.description).to eq("Custom start command removed for 'web' process. New environment variables deployed.")
        end

        context 'when sidecars have been added' do
          let!(:sidecar) { SidecarModel.make(app: app) }
          it 'creates a revision from the app values' do
            RevisionModel.make(
              app: app,
              droplet: app.droplet,
              environment_variables: app.environment_variables,
            )

            expect {
              RevisionResolver.update_app_revision(app, user_audit_info)
            }.to change { RevisionModel.where(app: app).count }.by(1)
            revision = RevisionModel.where(app: app).last
            expect(revision.sidecars.first.to_hash).to eq(sidecar.to_hash)
            expect(revision.description).to eq('Sidecars updated.')
          end
        end
      end

      context 'when the latest revisions is up to date' do
        it 'returns the latest_revision' do
          RevisionModel.make(
            app: app,
            droplet: app.droplet,
            environment_variables: app.environment_variables,
          )

          revision = nil
          expect {
            revision = RevisionResolver.update_app_revision(app, user_audit_info)
          }.to change { RevisionModel.where(app: app).count }.by(0), RevisionModel.last.description

          expect(revision).to eq(app.latest_revision)
        end
      end
    end

    describe '.rollback_app_revision' do
      let(:initial_revision) do
        RevisionModel.make(:custom_web_command,
          version: 1,
          droplet: droplet,
          app: app,
          environment_variables: { BISH: 'BASH', FOO: 'BAR' }
        )
      end

      before do
        initial_revision.
          process_commands_dataset.
          first(process_type: 'worker').
          update(process_command: 'on the railroad')
      end

      context 'when revisions are disabled' do
        before do
          app.update(revisions_enabled: false)
        end

        it 'return nil' do
          expect {
            expect(RevisionResolver.rollback_app_revision(app, initial_revision, user_audit_info)).to be_nil
          }.not_to change { RevisionModel.count }
        end
      end

      context 'when revisions are enabled' do
        let!(:latest_revision) {
          RevisionModel.make(:custom_web_command,
            app: app,
            droplet: app.droplet,
            environment_variables: { 'foo' => 'bar' },
            description: ['latest revision'],
            version: 2
          )
        }

        context 'rolling back' do
          it 'creates a new rollback revision' do
            rollback_revision = RevisionResolver.rollback_app_revision(app, initial_revision, user_audit_info)

            expect(rollback_revision.description).to include('Rolled back to revision 1.')
            expect(rollback_revision.app).to eq(initial_revision.app)
            expect(rollback_revision.droplet).to eq(initial_revision.droplet)
            expect(rollback_revision.environment_variables).to eq(initial_revision.environment_variables)
            expect(rollback_revision.commands_by_process_type).to eq(initial_revision.commands_by_process_type)
            expect(rollback_revision.process_commands).not_to eq(initial_revision.process_commands)
          end

          it 'does not copy metadata to the new rollback revision' do
            RevisionAnnotationModel.make(revision: initial_revision, key: 'foo', value: 'bar')
            RevisionLabelModel.make(revision: initial_revision, key_name: 'baz', value: 'qux')

            rollback_revision = RevisionResolver.rollback_app_revision(app, initial_revision, user_audit_info)

            expect(rollback_revision.annotations).to be_empty
            expect(rollback_revision.labels).to be_empty
          end
        end

        context 'and rolling back to a revision that has the same configuration as the deployed revision' do
          it 'gives an error and does not create a revision' do
            RevisionResolver.rollback_app_revision(app, initial_revision, user_audit_info)

            expect {
              expect {
                RevisionResolver.rollback_app_revision(app, initial_revision, user_audit_info)
              }.to raise_error(RevisionResolver::NoUpdateRollback, 'Unable to rollback. The code and configuration you are rolling back to is the same as the deployed revision.')
            }.not_to change { RevisionModel.count }
          end
        end
      end
    end
  end
end
