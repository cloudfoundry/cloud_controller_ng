require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe AppUsageEventsCleanup do
      let(:event_from_29_days_ago) { AppUsageEvent.make(created_at: 28.days.ago) }
      let(:event_from_30_days_ago) { AppUsageEvent.make(created_at: 30.days.ago) }
      let(:event_from_31_days_ago) { AppUsageEvent.make(created_at: 32.days.ago) }
      let(:event_from_90_days_ago) { AppUsageEvent.make(created_at: 90.days.ago) }

      subject(:job) do
        AppUsageEventsCleanup.new
      end

      before do
        allow(Steno).to receive(:logger).and_return(double(Steno::Logger).as_null_object)
      end

      it "can be enqueued" do
        expect(job).to respond_to(:perform)
      end

      describe "#perform" do
        it "deletes events created more than 30 days ago" do
          expect {
            job.perform
          }.to change { event_from_31_days_ago.exists? }.to(false)
        end

        it "deletes really old events in case it hasn't run in a while" do
          expect {
            job.perform
          }.to change { event_from_90_days_ago.exists? }.to(false)
        end

        it "keeps events created 30 days ago" do
          expect {
            job.perform
          }.not_to change { event_from_30_days_ago.exists? }.from(true)
        end

        it "keeps events created less than 30 days ago" do
          expect {
            job.perform
          }.not_to change { event_from_29_days_ago.exists? }.from(true)
        end
      end
    end
  end
end
