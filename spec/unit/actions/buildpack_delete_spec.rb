require 'spec_helper'
require 'actions/buildpack_delete'

module VCAP::CloudController
  RSpec.describe BuildpackDelete do
    subject(:buildpack_delete) { BuildpackDelete.new }

    describe '#delete' do
      let!(:buildpack) { Buildpack.make }

      it 'deletes the buildpack record' do
        expect {
          buildpack_delete.delete([buildpack])
        }.to change { Buildpack.count }.by(-1)
        expect { buildpack.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      context 'when the buildpack has associated bits in the blobstore' do
        before do
          buildpack.update(key: 'the-key')
        end

        it 'schedules a job to the delete the blobstore item' do
          expect {
            buildpack_delete.delete([buildpack])
          }.to change {
            Delayed::Job.count
          }.by(1)

          job = Delayed::Job.last
          expect(job.handler).to include('VCAP::CloudController::Jobs::Runtime::BlobstoreDelete')
          expect(job.handler).to include("key: #{buildpack.key}")
          expect(job.handler).to include('buildpack_blobstore')
          expect(job.queue).to eq('cc-generic')
          expect(job.guid).not_to be_nil
        end
      end

      context 'when the buildpack does not have a blobstore key' do
        before do
          buildpack.update(key: nil)
        end

        it 'does not schedule a blobstore delete job' do
          expect {
            buildpack_delete.delete([buildpack])
          }.not_to change {
            Delayed::Job.count
          }
        end
      end
    end
  end
end
