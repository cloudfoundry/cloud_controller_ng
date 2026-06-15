require 'spec_helper'

module VCAP::CloudController
  module Jobs::Services
    RSpec.describe ServiceUsageEventsCleanup, job_context: :worker do
      let(:cutoff_age_in_days) { 30 }
      let(:logger) { double(Steno::Logger, info: nil) }
      let!(:event_before_threshold) { ServiceUsageEvent.make(created_at: (cutoff_age_in_days + 1).days.ago, state: 'DELETED') }
      let!(:event_after_threshold) { ServiceUsageEvent.make(created_at: (cutoff_age_in_days - 1).days.ago) }

      subject(:job) do
        ServiceUsageEventsCleanup.new(cutoff_age_in_days)
      end

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      it { is_expected.to be_a_valid_job }

      it 'can be enqueued' do
        expect(job).to respond_to(:perform)
      end

      describe '#perform' do
        it 'deletes events created before the pruning threshold' do
          expect do
            job.perform
          end.to change(event_before_threshold, :exists?).to(false)
        end

        it 'keeps events created after the pruning threshold' do
          expect do
            job.perform
          end.not_to change(event_after_threshold, :exists?).from(true)
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:service_usage_events_cleanup)
        end
      end
    end
  end
end
