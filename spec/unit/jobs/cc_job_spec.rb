require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe CCJob, job_context: :worker do
      before { GenericEnqueuer.reset! } # Reset singleton instance to ensure clean tests

      describe '#reschedule_at' do
        it 'uses the default from Delayed::Job' do
          time = Time.now
          attempts = 5
          job = CCJob.new
          expect(job.reschedule_at(time, attempts)).to eq(time + (attempts**4) + 5)
        end
      end

      describe '#before' do
        class DummyDelayedJob
          attr_reader :priority

          def initialize(priority:)
            @priority = priority
          end
        end

        it 'creates a new GenericEnqueuer with the priority from the job' do
          job = CCJob.new
          job.before(DummyDelayedJob.new(priority: 5))
          expect(Thread.current[:generic_enqueuer].instance_values['opts'][:priority]).to eq(5)
        end
      end

      describe '#after' do
        it 'resets the GenericEnqueuer' do
          job = CCJob.new
          expect(Thread.current[:generic_enqueuer]).to be_nil
          job.before(DummyDelayedJob.new(priority: 5))
          expect(Thread.current[:generic_enqueuer]).to be_a(GenericEnqueuer)
          job.after(nil)
          expect(Thread.current[:generic_enqueuer]).to be_nil
        end
      end
    end
  end
end
