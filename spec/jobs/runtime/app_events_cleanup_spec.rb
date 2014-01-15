require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe AppEventsCleanup do
      let(:cutoff_age_in_days) { 2 }
      subject(:job) { AppEventsCleanup.new(cutoff_age_in_days) }

      before do
        @old_event = AppEvent.make(created_at: 3.days.ago)
        @event = AppEvent.make(created_at: 1.days.ago)
      end

      it "removes app events that are older than the specfied cutoff age" do
        expect {
          job.perform
        }.to change { AppEvent.find(id: @old_event.id) }.to(nil)
      end

      it "leaves the events that are younger than the specifed cutoff age" do
        expect {
          job.perform
        }.not_to change { AppEvent.find(id: @event.id) }.to(nil)
      end

      it "times out if the job takes longer than its timeout" do
        AppEvent.stub(:where) do
          sleep 2
        end

        job.stub(:max_run_time) { 1 }

        expect {
          job.perform
        }.to raise_error(Timeout::Error)
      end
    end
  end
end
