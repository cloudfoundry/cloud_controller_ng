require 'spec_helper'
require 'actions/buildpack_delete'

module VCAP::CloudController
  RSpec.describe BuildpackDelete do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_name) { 'user-name' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email, user_name: user_name) }

    subject(:buildpack_delete) { BuildpackDelete.new(user_audit_info) }

    describe '#delete' do
      let!(:buildpack) { Buildpack.make }

      it 'deletes the buildpack record' do
        expect do
          buildpack_delete.delete([buildpack])
        end.to change(Buildpack, :count).by(-1)
        expect { buildpack.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      it 'creates an audit event' do
        buildpack_guid = buildpack.guid
        buildpack_name = buildpack.name

        buildpack_delete.delete([buildpack])

        event = VCAP::CloudController::Event.last

        expect(event.values).to include(
          type: 'audit.buildpack.delete',
          actee: buildpack_guid,
          actee_type: 'buildpack',
          actee_name: buildpack_name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          space_guid: '',
          organization_guid: ''
        )
        expect(event.metadata).to eq({})
        expect(event.timestamp).to be
      end

      context 'when the buildpack has associated bits in the blobstore' do
        before do
          buildpack.update(key: 'the-key')
        end

        it 'schedules a job to the delete the blobstore item' do
          expect do
            buildpack_delete.delete([buildpack])
          end.to change(Delayed::Job, :count).by(1)

          job = Delayed::Job.last
          expect(job.handler).to include('VCAP::CloudController::Jobs::Runtime::BlobstoreDelete')
          expect(job.handler).to match(/key: ['"]?#{buildpack.key}/)
          expect(job.handler).to include('buildpack_blobstore')
          expect(job.queue).to eq(Jobs::Queues.generic)
          expect(job.guid).not_to be_nil
        end

        it 'first deletes the database record and afterwards the blob' do
          expect(buildpack).to receive(:destroy).ordered
          expect(Jobs::Runtime::BlobstoreDelete).to receive(:new).ordered
          generic_enqueuer_dbl = double('Jobs::GenericEnqueuer')
          expect(Jobs::GenericEnqueuer).to receive(:shared).and_return(generic_enqueuer_dbl).ordered
          expect(generic_enqueuer_dbl).to receive(:enqueue).ordered

          buildpack_delete.delete([buildpack])
        end
      end

      context 'when the buildpack has associated metadata' do
        let!(:label) { BuildpackLabelModel.make(resource_guid: buildpack.guid, key_name: 'test', value: 'bommel') }
        let!(:annotation) { BuildpackAnnotationModel.make(resource_guid: buildpack.guid, key_name: 'test', value: 'bommel') }

        it 'deletes associated labels' do
          expect do
            buildpack_delete.delete([buildpack])
          end.to change(BuildpackLabelModel, :count).by(-1)
          expect(label).not_to exist
          expect(buildpack).not_to exist
        end

        it 'deletes associated annotations' do
          expect do
            buildpack_delete.delete([buildpack])
          end.to change(BuildpackAnnotationModel, :count).by(-1)
          expect(annotation).not_to exist
          expect(buildpack).not_to exist
        end
      end

      context 'when the buildpack does not have a blobstore key' do
        before do
          buildpack.update(key: nil)
        end

        it 'does not schedule a blobstore delete job' do
          expect do
            buildpack_delete.delete([buildpack])
          end.not_to(change(Delayed::Job, :count))
        end
      end
    end
  end
end
