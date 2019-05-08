require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe EventsCleanup, job_context: :worker do
      let(:cutoff_age_in_days) { 2 }
      let!(:old_event) { Event.make(created_at: 3.days.ago) }
      let!(:event) { Event.make(created_at: 1.days.ago) }
      subject(:job) { EventsCleanup.new(cutoff_age_in_days) }

      it { is_expected.to be_a_valid_job }

      it 'removes app events that are older than the specified cutoff age' do
        expect {
          job.perform
        }.to change { Event.find(id: old_event.id) }.to(nil)
      end

      it 'leaves the events that are younger than the specified cutoff age' do
        expect {
          job.perform
        }.not_to change { Event.find(id: event.id) }
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:events_cleanup)
      end
    end
  end
end
