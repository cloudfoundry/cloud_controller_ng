require 'spec_helper'

RSpec.describe DeserializationRetry do
  context 'when a Delayed::Job fails to load because the class is missing' do
    it 'prevents DelayedJob from marking it as failed' do
      handler = VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(10_000)
      VCAP::CloudController::Jobs::Enqueuer.new(handler).enqueue

      job = Delayed::Job.last
      job.update handler: job.handler.gsub('EventsCleanup', 'Dan')

      Delayed::Worker.new.work_off

      job.reload
      expect(job.failed_at).to be_nil
      expect(job.locked_by).to be_nil
      expect(job.locked_at).to be_nil

      expect(job.run_at).to be_within(2.seconds).of Delayed::Job.db_time_now + 5.minutes
      expect(job.attempts).to eq(1)
    end

    context 'and we have been retrying for more than 24 hours' do
      it 'stops retrying the job' do
        handler = VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(10_000)
        VCAP::CloudController::Jobs::Enqueuer.new(handler).enqueue

        job = Delayed::Job.last
        job.update handler: job.handler.gsub('EventsCleanup', 'Dan'), created_at: Delayed::Job.db_time_now - 24.hours - 1.second

        Delayed::Worker.new.work_off

        expect(job.reload.failed_at).not_to be_nil
      end
    end
  end

  context 'when a Delayed::Job fails to load because of another reason' do
    it 'allows the job to be marked as failed' do
      handler = VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(10_000)
      VCAP::CloudController::Jobs::Enqueuer.new(handler).enqueue

      job = Delayed::Job.last
      job.update handler: 'Dan'

      execute_all_jobs(expected_successes: 0, expected_failures: 1)
      expect(job.reload.attempts).to eq(1)
    end
  end

  context 'when the Delayed::Job is well formed' do
    it 'executes the job' do
      handler = VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(10_000)
      VCAP::CloudController::Jobs::Enqueuer.new(handler).enqueue

      execute_all_jobs(expected_successes: 1, expected_failures: 0)
    end

    context 'and the job blows up during execution' do
      class BoomJob < VCAP::CloudController::Jobs::CCJob
        def perform
          raise 'BOOOM!'
        end
      end

      it 'does not retry' do
        handler = BoomJob.new
        VCAP::CloudController::Jobs::Enqueuer.new(handler).enqueue

        job = Delayed::Job.last
        old_run_at = job.run_at

        execute_all_jobs(expected_successes: 0, expected_failures: 1)

        expect(job.reload.run_at).to eq old_run_at
        expect(job.reload.failed_at).not_to be_nil
      end
    end
  end
end
