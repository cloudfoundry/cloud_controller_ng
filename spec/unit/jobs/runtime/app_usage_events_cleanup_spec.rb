require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe AppUsageEventsCleanup, job_context: :worker do
      let(:cutoff_age_in_days) { 30 }
      let(:logger) { double(Steno::Logger, info: nil) }
      let!(:start_event_before_threshold) { AppUsageEvent.make(app_guid: 'app-guid-1', state: 'STARTED', created_at: (cutoff_age_in_days + 1).days.ago) }
      let!(:stop_event_before_threshold) { AppUsageEvent.make(app_guid: 'app-guid-1', state: 'STOPPED', created_at: (cutoff_age_in_days + 1).days.ago) }
      let!(:start_event_after_threshold) { AppUsageEvent.make(app_guid: 'app-guid-2', state: 'STARTED', created_at: (cutoff_age_in_days - 1).days.ago) }
      let!(:stop_event_after_threshold) { AppUsageEvent.make(app_guid: 'app-guid-2', state: 'STOPPED', created_at: (cutoff_age_in_days - 1).days.ago) }

      subject(:job) do
        AppUsageEventsCleanup.new(cutoff_age_in_days)
      end

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      it { is_expected.to be_a_valid_job }

      it 'can be enqueued' do
        expect(job).to respond_to(:perform)
      end

      describe '#perform' do
        it 'deletes events created before the pruning threshold that have stop events' do
          expect {
            job.perform
          }.to change { start_event_before_threshold.exists? }.to(false)
        end

        it 'keeps events created after the pruning threshold' do
          expect {
            job.perform
          }.not_to change { start_event_after_threshold.exists? }.from(true)
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:app_usage_events_cleanup)
        end
      end
    end
  end
end
