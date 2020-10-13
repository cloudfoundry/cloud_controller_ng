require 'rails_helper'
require 'jobs/reoccurring_job'

module VCAP
  module CloudController
    class FakeJob < Jobs::ReoccurringJob
      attr_reader :calls, :expired, :expiry_time, :iterations, :warnings

      def initialize(iterations: 10, retry_after: [])
        @iterations = iterations
        @calls = 0
        @retry_after = retry_after
        super()
      end

      def display_name
        'fake-job'
      end

      def resource_guid
        'fake-resource-guid'
      end

      def resource_type
        'fake-resource-type'
      end

      def perform
        self.polling_interval_seconds = @retry_after[@calls] if @retry_after.length > @calls
        @calls += 1
        finish if @calls == iterations
      end
    end

    RSpec.describe Jobs::ReoccurringJob do
      after do
        Timecop.return
      end

      it_behaves_like 'delayed job', FakeJob

      it 'can be enqueued' do
        expect(PollableJobModel.all).to be_empty

        pollable_job = Jobs::Enqueuer.new(FakeJob.new, queue: Jobs::Queues.generic).enqueue_pollable

        expect(PollableJobModel.first).to eq(pollable_job)
      end

      it 'runs a first time' do
        Jobs::Enqueuer.new(FakeJob.new, queue: Jobs::Queues.generic).enqueue_pollable

        number_of_calls_to_job = Delayed::Job.last.payload_object.handler.handler.handler.calls
        expect(number_of_calls_to_job).to eq(0)

        execute_all_jobs(expected_successes: 1, expected_failures: 0, jobs_to_execute: 1)

        number_of_calls_to_job = Delayed::Job.last.payload_object.handler.handler.handler.calls
        expect(number_of_calls_to_job).to eq(1)
      end

      it 're-enqueues itself with a new delayed job' do
        pollable_job = Jobs::Enqueuer.new(FakeJob.new, queue: Jobs::Queues.generic).enqueue_pollable
        expect(PollableJobModel.all).to have(1).job

        execute_all_jobs(expected_successes: 1, expected_failures: 0, jobs_to_execute: 1)
        expect(PollableJobModel.all).to have(1).job

        expect(PollableJobModel.first.guid).to eq(pollable_job.guid)
        expect(PollableJobModel.first.delayed_job_guid).not_to eq(pollable_job.delayed_job_guid)
      end

      it 'waits for the polling interval' do
        job = FakeJob.new
        job.polling_interval_seconds = 95
        expect(job.polling_interval_seconds).to eq(95)

        enqueued_time = Time.now

        Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic).enqueue_pollable
        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        Timecop.freeze(94.seconds.after(enqueued_time)) do
          execute_all_jobs(expected_successes: 0, expected_failures: 0)
        end

        Timecop.freeze(96.seconds.after(enqueued_time)) do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end
      end

      it 'keeps the polling interval within the bounds' do
        job = FakeJob.new
        job.polling_interval_seconds = 5
        expect(job.polling_interval_seconds).to eq(60)

        job.polling_interval_seconds = 10.days
        expect(job.polling_interval_seconds).to eq(24.hours)
      end

      context 'updates the polling interval if config changes' do
        it 'when changed from the job only' do
          job = FakeJob.new(retry_after: ['20', '30'])
          TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 10

          enqueued_time = Time.now

          Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic).enqueue_pollable
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          Timecop.freeze(19.seconds.after(enqueued_time)) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end

          Timecop.freeze(22.seconds.after(enqueued_time)) do
            enqueued_time = Time.now
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end

          Timecop.freeze(29.seconds.after(enqueued_time)) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end

          Timecop.freeze(32.seconds.after(enqueued_time)) do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end
        end

        it 'when default changed after changing from the job' do
          job = FakeJob.new(retry_after: [20])
          TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 10

          enqueued_time = Time.now

          Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic).enqueue_pollable
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          Timecop.freeze(19.seconds.after(enqueued_time)) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end

          Timecop.freeze(21.seconds.after(enqueued_time)) do
            TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 30
            enqueued_time = Time.now
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end

          Timecop.freeze(29.seconds.after(enqueued_time)) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end

          Timecop.freeze(31.seconds.after(enqueued_time)) do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end
        end

        it 'when changing default only' do
          job = FakeJob.new
          TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 10

          enqueued_time = Time.now

          Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic).enqueue_pollable
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          Timecop.freeze(9.seconds.after(enqueued_time)) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end

          Timecop.freeze(11.seconds.after(enqueued_time)) do
            TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 30
            enqueued_time = Time.now
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end

          Timecop.freeze(29.seconds.after(enqueued_time)) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end

          Timecop.freeze(31.seconds.after(enqueued_time)) do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end
        end
      end

      it 'continues to run until finished' do
        Jobs::Enqueuer.new(FakeJob.new, queue: Jobs::Queues.generic).enqueue_pollable

        10.times do
          Timecop.travel(61.seconds)
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end

        expect(PollableJobModel.first.state).to eq('COMPLETE')
      end

      context 'when the job raises' do
        class FakeFailingJob < FakeJob
          def perform
            raise 'boo!'
          end
        end

        it 'completes with a failed state' do
          Jobs::Enqueuer.new(FakeFailingJob.new, queue: Jobs::Queues.generic).enqueue_pollable

          execute_all_jobs(expected_successes: 0, expected_failures: 1)
          expect(PollableJobModel.first.state).to eq('FAILED')

          Timecop.freeze(61.seconds.after(Time.now)) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end
        end
      end

      context 'timeout' do
        it 'marks the job failed with a timeout error' do
          Jobs::Enqueuer.new(FakeJob.new, queue: Jobs::Queues.generic).enqueue_pollable

          Timecop.freeze(Time.now + VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes).minute + 1) do
            execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
            expect(PollableJobModel.first.state).to eq('FAILED')
            expect(PollableJobModel.first.cf_api_error).not_to be_nil
            error = YAML.safe_load(PollableJobModel.first.cf_api_error)
            expect(error['errors'].first['code']).to eq(290006)
            expect(error['errors'].first['detail']).
              to eq('The job execution has timed out.')
          end
        end

        it 'calls the `handle_timeout` method' do
          class FakeTimeoutJob < FakeJob
            def handle_timeout
              raise 'handle_timeout was called'
            end
          end

          Jobs::Enqueuer.new(FakeTimeoutJob.new, queue: Jobs::Queues.generic).enqueue_pollable

          Timecop.freeze(Time.now + VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes).minute + 1) do
            execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
            expect(Delayed::Job.last.last_error).to include('handle_timeout was called')
          end
        end

        it 'can be configured' do
          job = FakeJob.new
          job.polling_interval_seconds = 1.minute
          job.maximum_duration_seconds = 2.minutes

          Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic).enqueue_pollable

          Timecop.freeze(61.seconds.after(Time.now)) do
            execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
            expect(PollableJobModel.first.state).to eq('FAILED')
          end
        end

        it 'does not allow the maximum duration to exceed the platform maximum' do
          job = FakeJob.new
          job.maximum_duration_seconds = 1 + VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes).minute
          expect(job.maximum_duration_seconds).to eq(VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes)
        end
      end
    end
  end
end
