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
      GenericEnqueuer.reset!
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

    describe 'root context' do
      let(:job) { DummyPerformJob.new }

      describe '#activate_root_context' do
        it 'stamps root_job_guid onto pollable rows created while active' do
          enqueuer = generic_enqueuer.shared
          enqueuer.activate_root_context(root_job_guid: 'root-guid-1')

          pollable_job = enqueuer.enqueue_pollable(
            VCAP::CloudController::Jobs::DeleteActionJob.new(VCAP::CloudController::DropletModel, 'fake',
                                                             VCAP::CloudController::DropletDelete.new('fake'))
          )

          expect(pollable_job.root_job_guid).to eq('root-guid-1')
        end

        it 'stamps root_job_guid onto every pollable row created while active' do
          enqueuer = generic_enqueuer.shared
          enqueuer.activate_root_context(root_job_guid: 'root-guid-1')

          first = enqueuer.enqueue_pollable(
            VCAP::CloudController::Jobs::DeleteActionJob.new(VCAP::CloudController::DropletModel, 'fake-1',
                                                             VCAP::CloudController::DropletDelete.new('fake-1'))
          )
          second = enqueuer.enqueue_pollable(
            VCAP::CloudController::Jobs::DeleteActionJob.new(VCAP::CloudController::DropletModel, 'fake-2',
                                                             VCAP::CloudController::DropletDelete.new('fake-2'))
          )

          expect(first.root_job_guid).to eq('root-guid-1')
          expect(second.root_job_guid).to eq('root-guid-1')
        end
      end

      describe '#deactivate_root_context' do
        it 'clears the root_job_guid' do
          enqueuer = generic_enqueuer.shared
          enqueuer.activate_root_context(root_job_guid: 'root-guid-1')
          enqueuer.deactivate_root_context

          expect(enqueuer.root_job_guid).to be_nil
        end

        it 'subsequent enqueues no longer carry the root_job_guid' do
          enqueuer = generic_enqueuer.shared
          enqueuer.activate_root_context(root_job_guid: 'root-guid-1')
          enqueuer.deactivate_root_context

          pollable_job = enqueuer.enqueue_pollable(
            VCAP::CloudController::Jobs::DeleteActionJob.new(VCAP::CloudController::DropletModel, 'fake',
                                                             VCAP::CloudController::DropletDelete.new('fake'))
          )

          expect(pollable_job.root_job_guid).to be_nil
        end
      end

      describe 'without an active root context (default)' do
        it 'enqueues pollable jobs with root_job_guid nil' do
          enqueuer = generic_enqueuer.shared

          pollable_job = enqueuer.enqueue_pollable(
            VCAP::CloudController::Jobs::DeleteActionJob.new(VCAP::CloudController::DropletModel, 'fake',
                                                             VCAP::CloudController::DropletDelete.new('fake'))
          )

          expect(pollable_job.root_job_guid).to be_nil
        end
      end
    end
  end
end
