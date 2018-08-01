require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe EventsCleanup do
      let(:cutoff_age_in_days) { 2 }
      subject(:job) { EventsCleanup.new(cutoff_age_in_days) }

      before do
        @old_event = Event.make(created_at: 3.days.ago)
        @event = Event.make(created_at: 1.days.ago)
      end

      it { is_expected.to be_a_valid_job }

      it 'removes app events that are older than the specfied cutoff age' do
        expect {
          job.perform
        }.to change { Event.find(id: @old_event.id) }.to(nil)
      end

      it 'leaves the events that are younger than the specifed cutoff age' do
        expect {
          job.perform
        }.not_to change { Event.find(id: @event.id) }
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:events_cleanup)
      end
    end
  end
end
