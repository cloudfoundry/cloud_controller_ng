require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe AppUsageEventsCleanup do
      let(:prune_threshold_in_days) { 30 }
      let(:logger) { double(Steno::Logger, info: nil) }

      subject(:job) do
        AppUsageEventsCleanup.new(prune_threshold_in_days)
      end

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      it "can be enqueued" do
        expect(job).to respond_to(:perform)
      end

      describe "#perform" do
        it "logs the number of deletions" do
          3.times { AppUsageEvent.make(created_at: (prune_threshold_in_days + 1).days.ago) }
          expect(logger).to receive(:info).with("Ran AppUsageEventsCleanup, deleted 3 events")
          job.perform
        end

        it "deletes events created before the pruning threshold" do
          Timecop.freeze do
            event_before_threshold = AppUsageEvent.make(created_at: (prune_threshold_in_days + 1).days.ago)
            expect {
              job.perform
            }.to change { event_before_threshold.exists? }.to(false)
          end
        end

        it "keeps events created  at the pruning threshold" do
          Timecop.freeze do
            event_at_threshold = AppUsageEvent.make(created_at: prune_threshold_in_days.days.ago)
            expect {
              job.perform
            }.not_to change { event_at_threshold.exists? }.from(true)
          end
        end

        it "keeps events created after the pruning threshold" do
          Timecop.freeze do
            event_after_threshold = AppUsageEvent.make(created_at: (prune_threshold_in_days - 1).days.ago)
            expect {
              job.perform
            }.not_to change { event_after_threshold.exists? }.from(true)
          end
        end
      end
    end
  end
end
