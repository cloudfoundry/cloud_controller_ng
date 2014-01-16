require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe EventsCleanup do
      let(:cutoff_age_in_days) { 2 }
      subject(:job) { EventsCleanup.new(cutoff_age_in_days) }

      before do
        @old_event = Event.make(created_at: 3.days.ago)
        @event = Event.make(created_at: 1.days.ago)
      end

      it "removes app events that are older than the specfied cutoff age" do
        expect {
          job.perform
        }.to change { Event.find(id: @old_event.id) }.to(nil)
      end

      it "leaves the events that are younger than the specifed cutoff age" do
        expect {
          job.perform
        }.not_to change { Event.find(id: @event.id) }.to(nil)
      end

      it "times out if the job takes longer than its timeout" do
        Event.stub(:where) do
          sleep 2
        end

        job.stub(:max_run_time).with(:events_cleanup).and_return( 0.001 )

        expect {
          job.perform
        }.to raise_error(Timeout::Error)
      end
    end
  end
end
