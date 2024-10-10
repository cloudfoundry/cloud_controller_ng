require 'spec_helper'
require 'actions/droplet_delete'

module VCAP::CloudController
  RSpec.describe DropletDelete do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'user@example.com', user_guid: user.guid) }

    subject(:droplet_delete) { DropletDelete.new(user_audit_info) }

    describe '#delete' do
      let!(:droplet) { DropletModel.make }

      let!(:label) do
        VCAP::CloudController::DropletLabelModel.make(
          key_prefix: 'indiana.edu',
          key_name: 'state',
          value: 'Indiana',
          resource_guid: droplet.guid
        )
      end

      before do
        droplet.app.update(droplet_guid: nil)
      end

      it 'deletes the droplet record' do
        expect do
          droplet_delete.delete([droplet])
        end.to change(DropletModel, :count).by(-1)
        expect { droplet.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      it 'deletes associated metadata' do
        expect do
          droplet_delete.delete([droplet])
        end.to change(DropletLabelModel, :count).by(-1)
        expect { label.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      it 'creates an audit event' do
        expect(Repositories::DropletEventRepository).to receive(:record_delete).with(
          instance_of(DropletModel),
          user_audit_info,
          droplet.app.name,
          droplet.app.space_guid,
          droplet.app.space.organization_guid
        )

        droplet_delete.delete([droplet])
      end

      it 'schedules a job to the delete the blobstore item' do
        expect do
          droplet_delete.delete([droplet])
        end.to change(Delayed::Job, :count).by(1)

        job = Delayed::Job.last
        job_delete_handler = YAML.safe_load(job.handler, permitted_classes: [
          VCAP::CloudController::Jobs::LoggingContextJob,
          VCAP::CloudController::Jobs::TimeoutJob,
          VCAP::CloudController::Jobs::Runtime::BlobstoreDelete,
          Symbol
        ]).handler.handler

        expect(job_delete_handler.class).to eq(VCAP::CloudController::Jobs::Runtime::BlobstoreDelete)
        expect(job_delete_handler.key).to eq(droplet.blobstore_key)
        expect(job_delete_handler.blobstore_name).to eq(:droplet_blobstore)
        expect(job.queue).to eq(Jobs::Queues.generic)
        expect(job.guid).not_to be_nil
      end

      context 'when droplet is referenced as current droplet by an app' do
        before do
          droplet.app.update(droplet_guid: droplet.guid)
        end

        it 'raises an UnprocessableEntity error' do
          expect do
            droplet_delete.delete([droplet])
          end.to raise_error do |error|
            expect(error).to be_a(CloudController::Errors::ApiError)
            expect(error.name).to eq('UnprocessableEntity')
            expect(error.message).to match(/^The droplet is currently used.*/)
          end
        end

        it 'does not delete the droplet' do
          expect do
            expect { droplet_delete.delete([droplet]) }.to raise_error(CloudController::Errors::ApiError)
          end.not_to(change(DropletModel, :count))
        end

        it 'does not create an audit event' do
          expect(Repositories::DropletEventRepository).not_to receive(:record_delete)

          expect { droplet_delete.delete([droplet]) }.to raise_error(CloudController::Errors::ApiError)
        end

        it 'does not schedule a blobstore delete job' do
          expect do
            expect { droplet_delete.delete([droplet]) }.to raise_error(CloudController::Errors::ApiError)
          end.not_to(change(Delayed::Job, :count))
        end
      end

      context 'when the droplet does not have a blobstore key' do
        before do
          allow(droplet).to receive(:blobstore_key).and_return(nil)
        end

        it 'does not schedule a blobstore delete job' do
          expect do
            droplet_delete.delete([droplet])
          end.not_to(change(Delayed::Job, :count))
        end
      end
    end
  end
end
