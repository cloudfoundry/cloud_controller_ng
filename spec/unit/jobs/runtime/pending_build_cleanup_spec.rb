require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PendingBuildCleanup, job_context: :worker do
      subject(:cleanup_job) { PendingBuildCleanup.new(expiration_in_seconds: 15.minutes.to_i) }
      let(:staging_timeout) { 15.minutes.to_i }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(cleanup_job.job_name_in_configuration).to equal(:pending_builds)
      end

      describe '#perform' do
        let(:expired_time) { Time.now.utc - staging_timeout - PendingBuildCleanup::ADDITIONAL_EXPIRATION_TIME_IN_SECONDS - 1.minute }
        let(:non_expired_time) { Time.now.utc - staging_timeout - 1.minute }
        let(:fake_logger) { instance_double(Steno::Logger, error: nil, info: nil) }

        context 'with builds which have been staging for too long' do
          let!(:build1) { BuildModel.make(state: BuildModel::STAGING_STATE) }
          let!(:build2) { BuildModel.make(state: BuildModel::STAGING_STATE) }

          before do
            allow(Steno).to receive(:logger).and_return(fake_logger)
            build1.this.update(updated_at: expired_time)
            build2.this.update(updated_at: expired_time)
          end

          it 'marks builds as failed' do
            cleanup_job.perform

            expect(build1.reload.failed?).to be_truthy
            expect(build2.reload.failed?).to be_truthy
          end

          it 'logs that it failed the builds' do
            cleanup_job.perform

            expect(fake_logger).to have_received(:info).with("Staging timeout has elapsed for build: #{build1.guid}", build_guid: build1.guid)
            expect(fake_logger).to have_received(:info).with("Staging timeout has elapsed for build: #{build2.guid}", build_guid: build2.guid)
          end

          it 'sets the error_id' do
            cleanup_job.perform

            expect(build1.reload.error_id).to eq('StagingTimeExpired')
            expect(build2.reload.error_id).to eq('StagingTimeExpired')
          end

          it 'updates updated_at since we do not update through the model' do
            expect { cleanup_job.perform }.to change { build1.reload.updated_at }
          end
        end

        context 'when the builds were created recently' do
          let!(:build1) { BuildModel.make(state: BuildModel::STAGING_STATE) }
          let!(:build2) { BuildModel.make(state: BuildModel::STAGING_STATE) }

          before do
            build1.this.update(updated_at: non_expired_time, created_at: non_expired_time)
            build2.this.update(updated_at: non_expired_time, created_at: non_expired_time)
          end

          it 'does NOT fail them' do
            expect {
              cleanup_job.perform
            }.not_to change {
              [build1.reload.updated_at, build2.reload.updated_at]
            }

            expect(build1.reload.failed?).to be_falsey
            expect(build2.reload.failed?).to be_falsey
          end
        end

        it 'ignores builds that have not been staging for too long' do
          build1 = BuildModel.make(state: BuildModel::STAGING_STATE)
          build2 = BuildModel.make(state: BuildModel::STAGING_STATE)

          cleanup_job.perform

          expect(build1.reload.failed?).to be_falsey
          expect(build2.reload.failed?).to be_falsey
        end

        it 'ignores builds in a completed state' do
          build1 = BuildModel.make(state: BuildModel::STAGED_STATE)
          build2 = BuildModel.make(state: BuildModel::STAGED_STATE)
          build1.this.update(updated_at: expired_time)
          build2.this.update(updated_at: expired_time)

          cleanup_job.perform

          expect(build1.reload.failed?).to be_falsey
          expect(build2.reload.failed?).to be_falsey
        end
      end
    end
  end
end
