require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe AppUsageSnapshotCleanup, job_context: :worker do
      let(:cutoff_age_in_days) { 30 }
      let(:logger) { double(Steno::Logger, info: nil) }

      subject(:job) do
        AppUsageSnapshotCleanup.new(cutoff_age_in_days)
      end

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      it { is_expected.to be_a_valid_job }

      it 'can be enqueued' do
        expect(job).to respond_to(:perform)
      end

      describe '#perform' do
        context 'with old completed snapshots' do
          let!(:old_completed_snapshot) do
            AppUsageSnapshot.make(
              created_at: (cutoff_age_in_days + 1).days.ago,
              completed_at: cutoff_age_in_days.days.ago
            )
          end

          let!(:recent_completed_snapshot) do
            AppUsageSnapshot.make(
              created_at: (cutoff_age_in_days - 1).days.ago,
              completed_at: (cutoff_age_in_days - 1).days.ago
            )
          end

          it 'deletes old completed snapshots past the retention period' do
            expect do
              job.perform
            end.to change(old_completed_snapshot, :exists?).to(false)
          end

          it 'keeps recent completed snapshots' do
            expect do
              job.perform
            end.not_to change(recent_completed_snapshot, :exists?).from(true)
          end
        end

        context 'with stale in-progress snapshots' do
          let!(:stale_in_progress_snapshot) do
            AppUsageSnapshot.make(
              created_at: 2.hours.ago,
              completed_at: nil
            )
          end

          let!(:recent_in_progress_snapshot) do
            AppUsageSnapshot.make(
              created_at: 30.minutes.ago,
              completed_at: nil
            )
          end

          it 'deletes stale in-progress snapshots (older than 1 hour)' do
            expect do
              job.perform
            end.to change(stale_in_progress_snapshot, :exists?).to(false)
          end

          it 'keeps recent in-progress snapshots (less than 1 hour old)' do
            expect do
              job.perform
            end.not_to change(recent_in_progress_snapshot, :exists?).from(true)
          end
        end

        context 'with a mix of snapshot states' do
          let!(:old_completed) do
            AppUsageSnapshot.make(
              created_at: 60.days.ago,
              completed_at: 60.days.ago
            )
          end

          let!(:stale_in_progress) do
            AppUsageSnapshot.make(
              created_at: 2.hours.ago,
              completed_at: nil
            )
          end

          let!(:recent_completed) do
            AppUsageSnapshot.make(
              created_at: 1.day.ago,
              completed_at: 1.day.ago
            )
          end

          let!(:recent_in_progress) do
            AppUsageSnapshot.make(
              created_at: 30.minutes.ago,
              completed_at: nil
            )
          end

          it 'deletes old completed and stale in-progress, keeps recent ones' do
            expect { job.perform }.to change(AppUsageSnapshot, :count).by(-2)

            expect(old_completed.exists?).to be false
            expect(stale_in_progress.exists?).to be false
            expect(recent_completed.exists?).to be true
            expect(recent_in_progress.exists?).to be true
          end
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:app_usage_snapshot_cleanup)
        end

        it 'has max_attempts of 1' do
          expect(job.max_attempts).to eq(1)
        end
      end
    end
  end
end
