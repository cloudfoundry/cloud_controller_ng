require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PendingDropletCleanup do
      subject(:cleanup_job) { described_class.new(staging_timeout) }
      let(:staging_timeout) { 15.minutes.to_i }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(cleanup_job.job_name_in_configuration).to equal(:pending_droplets)
      end

      describe '#perform' do
        let(:expired_time) { Time.now.utc - staging_timeout - PendingDropletCleanup::ADDITIONAL_EXPIRATION_TIME_IN_SECONDS - 1.minute }
        let(:non_expired_time) { Time.now.utc - staging_timeout - 1.minute }

        context 'with droplets which have been staging or processing upload for too long' do
          let!(:droplet1) { DropletModel.make(state: DropletModel::STAGING_STATE) }
          let!(:droplet2) { DropletModel.make(state: DropletModel::STAGING_STATE) }
          let!(:droplet3) { DropletModel.make(state: DropletModel::PROCESSING_UPLOAD_STATE) }

          before do
            droplet1.this.update(updated_at: expired_time)
            droplet2.this.update(updated_at: expired_time)
            droplet3.this.update(updated_at: expired_time)
          end

          it 'marks droplets as failed' do
            cleanup_job.perform

            expect(droplet1.reload.failed?).to be_truthy
            expect(droplet2.reload.failed?).to be_truthy
            expect(droplet3.reload.failed?).to be_truthy
          end

          it 'sets the error_id' do
            cleanup_job.perform

            expect(droplet1.reload.error_id).to eq('StagingTimeExpired')
            expect(droplet2.reload.error_id).to eq('StagingTimeExpired')
            expect(droplet3.reload.error_id).to eq('StagingTimeExpired')
          end

          it 'updates updated_at since we do not update through the model' do
            expect { cleanup_job.perform }.to change { droplet1.reload.updated_at }
          end
        end

        context 'with droplets which are staging or processing upload but have no updated_at (db specific)' do
          let!(:droplet1) { DropletModel.make(state: DropletModel::STAGING_STATE) }
          let!(:droplet2) { DropletModel.make(state: DropletModel::STAGING_STATE) }
          let!(:droplet3) { DropletModel.make(state: DropletModel::PROCESSING_UPLOAD_STATE) }
          let(:null_timestamp) do
            if droplet1.db.database_type == :postgres
              nil
            else
              '0000-00-00 00:00:00'
            end
          end

          context 'when the droplets were created too long ago' do
            before do
              droplet1.this.update(updated_at: null_timestamp, created_at: expired_time)
              droplet2.this.update(updated_at: null_timestamp, created_at: expired_time)
              droplet3.this.update(updated_at: null_timestamp, created_at: expired_time)

              expect(droplet1.reload.updated_at).to be_nil
              expect(droplet2.reload.updated_at).to be_nil
              expect(droplet3.reload.updated_at).to be_nil
            end

            it 'fails them' do
              cleanup_job.perform

              expect(droplet1.reload.failed?).to be_truthy
              expect(droplet2.reload.failed?).to be_truthy
              expect(droplet3.reload.failed?).to be_truthy
            end
          end

          context 'when the droplets were created recently' do
            before do
              droplet1.this.update(updated_at: null_timestamp, created_at: non_expired_time)
              droplet2.this.update(updated_at: null_timestamp, created_at: non_expired_time)
              droplet3.this.update(updated_at: null_timestamp, created_at: non_expired_time)

              expect(droplet1.reload.updated_at).to be_nil
              expect(droplet2.reload.updated_at).to be_nil
              expect(droplet3.reload.updated_at).to be_nil
            end

            it 'does NOT fail them' do
              cleanup_job.perform

              expect(droplet1.reload.failed?).to be_falsey
              expect(droplet2.reload.failed?).to be_falsey
              expect(droplet3.reload.failed?).to be_falsey
            end
          end
        end

        it 'ignores droplets that have not been staging or processing upload for too long' do
          droplet1 = DropletModel.make(state: DropletModel::STAGING_STATE)
          droplet2 = DropletModel.make(state: DropletModel::STAGING_STATE)
          droplet3 = DropletModel.make(state: DropletModel::PROCESSING_UPLOAD_STATE)
          droplet1.this.update(updated_at: non_expired_time)
          droplet2.this.update(updated_at: non_expired_time)
          droplet3.this.update(updated_at: non_expired_time)

          cleanup_job.perform

          expect(droplet1.reload.failed?).to be_falsey
          expect(droplet2.reload.failed?).to be_falsey
          expect(droplet3.reload.failed?).to be_falsey
        end

        it 'ignores droplets in a completed state' do
          droplet1 = DropletModel.make(state: DropletModel::EXPIRED_STATE)
          droplet2 = DropletModel.make(state: DropletModel::STAGED_STATE)
          droplet1.this.update(updated_at: expired_time)
          droplet2.this.update(updated_at: expired_time)

          cleanup_job.perform

          expect(droplet1.reload.failed?).to be_falsey
          expect(droplet2.reload.failed?).to be_falsey
        end
      end
    end
  end
end
