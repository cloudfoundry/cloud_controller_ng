require 'spec_helper'
require 'actions/buildpack_delete'

module VCAP::CloudController
  RSpec.describe BuildpackDelete do
    subject(:buildpack_delete) { BuildpackDelete.new }

    describe '#delete' do
      let!(:buildpack) { Buildpack.make }

      it 'deletes the buildpack record' do
        expect do
          buildpack_delete.delete([buildpack])
        end.to change(Buildpack, :count).by(-1)
        expect { buildpack.refresh }.to raise_error Sequel::Error, 'Record not found'
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
          enqueue_job_dbl = double('Jobs::Enqueuer')
          expect(Jobs::Enqueuer).to receive(:new).and_return(enqueue_job_dbl).ordered
          expect(enqueue_job_dbl).to receive(:enqueue).ordered

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
