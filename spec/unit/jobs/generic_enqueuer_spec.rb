require 'spec_helper'
require 'jobs/generic_enqueuer'
require 'jobs/cc_job'

module VCAP::CloudController::Jobs
  RSpec.describe GenericEnqueuer do
    let(:generic_enqueuer) { GenericEnqueuer }

    class DummyPerformJob < VCAP::CloudController::Jobs::CCJob
      def perform
        # dummy
      end
    end

    class DummyWrappingJob < VCAP::CloudController::Jobs::CCJob
      def perform
        sub_job = DummyPerformJob.new
        GenericEnqueuer.shared.enqueue(sub_job)
      end
    end

    before do
      # Reset singleton instance to ensure clean tests
      Thread.current[:generic_enqueuer] = nil
    end

    describe '.shared' do
      it 'returns the same instance when called multiple times' do
        enqueuer1 = generic_enqueuer.shared
        enqueuer2 = generic_enqueuer.shared

        expect(enqueuer1).to be(enqueuer2)
      end

      it 'creates a new instance if a priority is provided' do
        enqueuer1 = generic_enqueuer.shared(priority: 5)
        enqueuer2 = generic_enqueuer.shared(priority: 5)

        expect(enqueuer1).not_to be(enqueuer2)
      end

      it 'returns a new instance without a priority (uses the default of Delayed::Job)' do
        enqueuer = generic_enqueuer.shared
        expect(enqueuer.instance_variable_get(:@opts)[:priority]).to be_nil
      end

      it 'ensures calling shared with a priority always returns a new instance' do
        enqueuer_default = generic_enqueuer.shared
        enqueuer_with_priority = generic_enqueuer.shared(priority: 5)

        expect(enqueuer_default).not_to be(enqueuer_with_priority)
      end
    end

    describe '#enqueue' do
      let(:job) { DummyPerformJob.new }

      it 'ensures a job with no priority explicitly set defaults to DelayedJob behavior' do
        generic_enqueuer.shared.enqueue(job)

        expect(Delayed::Job.count).to eq(1)
        expect(Delayed::Job.first.priority).to eq(0)
      end

      it 'enqueues a job with the correct priority' do
        generic_enqueuer.shared(priority: 4).enqueue(job)

        expect(Delayed::Job.count).to eq(1)
        expect(Delayed::Job.first.priority).to eq(4)
      end
    end

    describe 'priority inheritance' do
      it 'ensures the same GenericEnqueuer instance is used for sub-jobs' do
        VCAP::CloudController::Jobs::GenericEnqueuer.shared(priority: 7).enqueue(DummyWrappingJob.new)
        expect(Delayed::Job.count).to eq(1)
        expect(Delayed::Job.first.priority).to eq(7)

        execute_all_jobs(expected_successes: 1, expected_failures: 0, jobs_to_execute: 1)
        expect(Delayed::Job.count).to eq(1)
        expect(Delayed::Job.first.priority).to eq(7)
      end
    end
  end
end
