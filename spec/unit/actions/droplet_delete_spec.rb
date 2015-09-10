require 'spec_helper'
require 'actions/droplet_delete'

module VCAP::CloudController
  describe DropletDelete do
    subject(:droplet_delete) { DropletDelete.new }

    describe '#delete' do
      let!(:droplet) { DropletModel.make(droplet_hash: 'droplet_hash') }

      it 'deletes the droplet record' do
        expect {
          droplet_delete.delete([droplet])
        }.to change { DropletModel.count }.by(-1)
        expect { droplet.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      it 'schedules a job to the delete the blobstore item' do
        expect {
          droplet_delete.delete([droplet])
        }.to change {
               Delayed::Job.count
             }.by(1)

        job = Delayed::Job.last
        expect(job.handler).to include('VCAP::CloudController::Jobs::Runtime::BlobstoreDelete')
        expect(job.handler).to include("key: #{droplet.blobstore_key}")
        expect(job.handler).to include('droplet_blobstore')
        expect(job.queue).to eq('cc-generic')
        expect(job.guid).not_to be_nil
      end

      context 'when the droplet does not have a blobstore key' do
        before do
          allow(droplet).to receive(:blobstore_key).and_return(nil)
        end

        it 'does not schedule a blobstore delete job' do
          expect {
            droplet_delete.delete([droplet])
          }.not_to change {
            Delayed::Job.count
          }
        end
      end
    end
  end
end
