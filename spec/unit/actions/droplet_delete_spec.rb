require 'spec_helper'
require 'actions/droplet_delete'

module VCAP::CloudController
  RSpec.describe DropletDelete do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:stagers) { instance_double(Stagers) }

    subject(:droplet_delete) { DropletDelete.new(user, user_email, stagers) }

    describe '#delete' do
      let!(:droplet) { DropletModel.make(:staged) }

      it 'deletes the droplet record' do
        expect {
          droplet_delete.delete([droplet])
        }.to change { DropletModel.count }.by(-1)
        expect { droplet.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      it 'creates an audit event' do
        expect(Repositories::DropletEventRepository).to receive(:record_delete).with(
          instance_of(DropletModel),
          user,
          user_email,
          droplet.app.name,
          droplet.app.space_guid,
          droplet.app.space.organization_guid
        )

        droplet_delete.delete([droplet])
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

      context 'when the droplet is staging' do
        let(:stager) { instance_double(Diego::Stager) }
        let!(:droplet) { DropletModel.make(state: DropletModel::STAGING_STATE) }

        before do
          allow(stagers).to receive(:stager_for_app).and_return(stager)
          allow(stager).to receive(:stop_stage)
        end

        it 'sends a stop staging request' do
          droplet_delete.delete([droplet])
          expect(stagers).to have_received(:stager_for_app).with(droplet.app)
          expect(stager).to have_received(:stop_stage).with(droplet.guid)
        end
      end
    end
  end
end
