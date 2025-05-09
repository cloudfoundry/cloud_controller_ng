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

        pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new)

        expect(PollableJobModel.first).to eq(pollable_job)
      end

      it 'runs a first time' do
        Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new)

        number_of_calls_to_job = Delayed::Job.last.payload_object.handler.handler.handler.calls
        expect(number_of_calls_to_job).to eq(0)

        execute_all_jobs(expected_successes: 1, expected_failures: 0, jobs_to_execute: 1)

        number_of_calls_to_job = Delayed::Job.last.payload_object.handler.handler.handler.calls
        expect(number_of_calls_to_job).to eq(1)
      end

      it 're-enqueues itself with a new delayed job' do
        pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new)
        expect(PollableJobModel.all).to have(1).job

        execute_all_jobs(expected_successes: 1, expected_failures: 0, jobs_to_execute: 1)
        expect(PollableJobModel.all).to have(1).job

        expect(PollableJobModel.first.guid).to eq(pollable_job.guid)
        expect(PollableJobModel.first.delayed_job_guid).not_to eq(pollable_job.delayed_job_guid)
      end

      it 'keeps the delayed job\'s priority when re-enqueuing' do
        TestConfig.config[:jobs][:priorities] = { 'fake-job': 20 }

        Jobs::GenericEnqueuer.reset! # Ensure no previous state interferes

        pollable_job = Jobs::Enqueuer.new({ queue: Jobs::Queues.generic, priority: 22 }).enqueue_pollable(FakeJob.new)
        first_delayed_job_guid = pollable_job.delayed_job_guid
        expect(Delayed::Job.where(guid: first_delayed_job_guid).first[:priority]).to eq(42)

        execute_all_jobs(expected_successes: 1, expected_failures: 0, jobs_to_execute: 1)

        pollable_job.reload
        second_delayed_job_guid = pollable_job.delayed_job_guid
        expect(Delayed::Job.where(guid: second_delayed_job_guid).first[:priority]).to eq(42)
        expect(first_delayed_job_guid).not_to eq(second_delayed_job_guid)
      end

      it 'waits for the polling interval' do
        job = FakeJob.new
        job.polling_interval_seconds = 95
        expect(job.polling_interval_seconds).to eq(95)

        enqueued_time = 0

        Timecop.freeze do
          Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          enqueued_time = Time.now
        end

        Timecop.freeze(94.seconds.after(enqueued_time)) do
          execute_all_jobs(expected_successes: 0, expected_failures: 0)
        end

        Timecop.freeze(96.seconds.after(enqueued_time)) do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end
      end

      it 'keeps the polling interval within the default bounds' do
        job = FakeJob.new
        job.polling_interval_seconds = 5
        expect(job.polling_interval_seconds).to eq(60)

        job.polling_interval_seconds = 10.days
        expect(job.polling_interval_seconds).to eq(24.hours)
      end

      context 'when maximum polling interval is configured' do
        before do
          TestConfig.config[:broker_client_max_async_poll_interval_seconds] = 1800
        end

        it 'limits the polling interval to the configured maximum' do
          job = FakeJob.new
          job.polling_interval_seconds = 10.days
          expect(job.polling_interval_seconds).to eq(1800)
        end
      end

      describe 'exponential backoff rate' do
        context 'when changing exponential backoff rate only' do
          before do
            TestConfig.config[:broker_client_async_poll_exponential_backoff_rate] = 2.0
          end

          it 'updates the polling interval' do
            enqueued_time = 0

            Timecop.freeze do
              Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              enqueued_time = Time.now
            end

            [60, 180, 420, 900, 1860].each do |seconds|
              Timecop.freeze((seconds - 1).seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze((seconds + 1).seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end
          end
        end

        context 'when changing exponential backoff rate and default polling interval' do
          before do
            TestConfig.config[:broker_client_async_poll_exponential_backoff_rate] = 1.3
            TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 10
          end

          it 'updates the polling interval' do
            enqueued_time = 0

            Timecop.freeze do
              Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              enqueued_time = Time.now
            end

            [10, 23, 39.9, 61.8, 90.4].each do |seconds|
              Timecop.freeze((seconds - 1).seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze((seconds.ceil + 1).seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end
          end
        end

        describe 'changing exponential backoff rate and retry_after from the job' do
          context 'when retry-after is larger than calculated backoff' do
            let(:fake_job) { FakeJob.new(retry_after: [20, 30]) }

            before do
              TestConfig.config[:broker_client_async_poll_exponential_backoff_rate] = 1.3
              TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 10
            end

            it 'uses retry-after interval' do
              enqueued_time = 0

              Timecop.freeze do
                Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(fake_job)
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
                enqueued_time = Time.now
              end

              # the job should run after 20s (20s > 10 * 1.3^0)
              Timecop.freeze(19.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze(21.seconds.after(enqueued_time)) do
                enqueued_time = Time.now
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end

              # the job should run after 30s (30s > 10 * 1.3^1)
              Timecop.freeze(29.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze(31.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end
          end

          context 'when retry-after is smaller than calculated backoff' do
            let(:fake_job) { FakeJob.new(retry_after: [10, 20]) }

            before do
              TestConfig.config[:broker_client_async_poll_exponential_backoff_rate] = 1.3
              TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 30
            end

            it 'uses calculated interval' do
              enqueued_time = 0

              Timecop.freeze do
                Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(fake_job)
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
                enqueued_time = Time.now
              end

              # the job should run after 30s (30s > 10s)
              Timecop.freeze(29.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze(31.seconds.after(enqueued_time)) do
                enqueued_time = Time.now
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end

              # the job should run after 30s (30s * 1.3^1 = 39 > 20s)
              Timecop.freeze(38.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze(40.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end
          end

          context 'when calculated backoff gets larger than retry-after' do
            let(:fake_job) { FakeJob.new(retry_after: [15, 15, 15]) }

            before do
              TestConfig.config[:broker_client_async_poll_exponential_backoff_rate] = 2
              TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 5
            end

            it 'uses retry-after until calculated backoff is larger' do
              enqueued_time = 0

              Timecop.freeze do
                Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(fake_job)
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
                enqueued_time = Time.now
              end

              # the job should run after 15s (15s > 5s (5 * 2^0))
              Timecop.freeze(14.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze(16.seconds.after(enqueued_time)) do
                enqueued_time = Time.now
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end

              # the job should run after 15s (15s > 10s (5 * 2^1))
              Timecop.freeze(14.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze(16.seconds.after(enqueued_time)) do
                enqueued_time = Time.now
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end

              # the job should run after 20s (20s > 15s (5 * 2^2))
              Timecop.freeze(19.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              Timecop.freeze(21.seconds.after(enqueued_time)) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end

            context 'when maximum polling interval is configured' do
              before do
                TestConfig.config[:broker_client_max_async_poll_interval_seconds] = 18
              end

              it 'limits the polling interval to the configured maximum' do
                enqueued_time = 0

                Timecop.freeze do
                  Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(fake_job)
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                  enqueued_time = Time.now
                end

                # the job should run after 15s (15s > 5s (5 * 2^0))
                Timecop.freeze(14.seconds.after(enqueued_time)) do
                  execute_all_jobs(expected_successes: 0, expected_failures: 0)
                end

                Timecop.freeze(16.seconds.after(enqueued_time)) do
                  enqueued_time = Time.now
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end

                # the job should run after 15s (15s > 10s (5 * 2^1))
                Timecop.freeze(14.seconds.after(enqueued_time)) do
                  execute_all_jobs(expected_successes: 0, expected_failures: 0)
                end

                Timecop.freeze(16.seconds.after(enqueued_time)) do
                  enqueued_time = Time.now
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end

                # the job should run after 18s (capped at )
                Timecop.freeze(17.seconds.after(enqueued_time)) do
                  execute_all_jobs(expected_successes: 0, expected_failures: 0)
                end

                Timecop.freeze(19.seconds.after(enqueued_time)) do
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end
            end
          end
        end

        it 'takes the exponential backoff into account when checking whether the next run would exceed the maximum duration' do
          TestConfig.config[:broker_client_async_poll_exponential_backoff_rate] = 1.3
          TestConfig.config[:broker_client_max_async_poll_duration_minutes] = 60

          job = FakeJob.new(iterations: 100)
          # With a backoff rate of 1.3, 11 jobs could have been executed in 60 minutes (initial run + 10 retries).
          job.instance_variable_set(:@retry_number, 10)

          enqueued_time = 0

          Timecop.freeze do
            Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)
            enqueued_time = Time.now
          end

          # The calculated backoff for the 11th retry would be 3384.321 seconds.
          Timecop.freeze(enqueued_time + 3384.321.ceil.seconds) do
            execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
            expect(PollableJobModel.first.state).to eq('FAILED')
            expect(PollableJobModel.first.cf_api_error).not_to be_nil
            error = YAML.safe_load(PollableJobModel.first.cf_api_error)
            expect(error['errors'].first['code']).to eq(290_006)
            expect(error['errors'].first['detail']).
              to eq('The job execution has timed out.')
          end
        end
      end

      context 'updates the polling interval if config changes' do
        it 'when changed from the job only' do
          TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 10

          enqueued_time = 0

          Timecop.freeze do
            Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new(retry_after: [20, 30]))
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            enqueued_time = Time.now
          end

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
          TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 10

          enqueued_time = 0

          Timecop.freeze do
            Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new(retry_after: [20]))
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            enqueued_time = Time.now
          end

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
          TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 10

          enqueued_time = 0

          Timecop.freeze do
            Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            enqueued_time = Time.now
          end

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
        Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new)

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
          Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeFailingJob.new)

          execute_all_jobs(expected_successes: 0, expected_failures: 1)
          expect(PollableJobModel.first.state).to eq('FAILED')

          Timecop.freeze(61.seconds.after(Time.now)) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end
        end
      end

      context 'timeout' do
        it 'marks the job failed with a timeout error' do
          Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeJob.new)

          Timecop.freeze(Time.now + VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes).minute + 1) do
            execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
            expect(PollableJobModel.first.state).to eq('FAILED')
            expect(PollableJobModel.first.cf_api_error).not_to be_nil
            error = YAML.safe_load(PollableJobModel.first.cf_api_error)
            expect(error['errors'].first['code']).to eq(290_006)
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

          Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(FakeTimeoutJob.new)

          Timecop.freeze(Time.now + VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes).minute + 1) do
            execute_all_jobs(expected_successes: 0, expected_failures: 1, jobs_to_execute: 1)
            expect(Delayed::Job.last.last_error).to include('handle_timeout was called')
          end
        end

        it 'can be configured' do
          job = FakeJob.new
          job.polling_interval_seconds = 1.minute
          job.maximum_duration_seconds = 2.minutes

          Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)

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
