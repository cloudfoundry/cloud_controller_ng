require 'jobs/cc_job'

module VCAP::CloudController
  module Jobs
    class ReoccurringJob < VCAP::CloudController::Jobs::CCJob
      attr_reader :finished, :start_time, :retry_number

      def success(current_delayed_job)
        pollable_job = PollableJobModel.find_by_delayed_job(current_delayed_job)

        if finished
          pollable_job.update(state: PollableJobModel::COMPLETE_STATE)
        elsif next_enqueue_would_exceed_maximum_duration?
          expire!
        else
          enqueue_next_job(pollable_job)
        end
      end

      def maximum_duration_seconds
        @maximum_duration || default_maximum_duration_seconds
      end

      def maximum_duration_seconds=(duration)
        @maximum_duration = if duration.present? && duration < default_maximum_duration_seconds
                              duration
                            else
                              default_maximum_duration_seconds
                            end
      end

      def polling_interval_seconds
        [@polling_interval || 0, default_polling_interval_seconds].max
      end

      def polling_interval_seconds=(interval)
        interval = interval.to_i if interval.is_a? String
        @polling_interval = interval.clamp(default_polling_interval_seconds, 24.hours)
      end

      private

      def initialize
        @start_time = Time.now
        @finished = false
        @retry_number = 0
      end

      def default_maximum_duration_seconds
        Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes
      end

      def default_polling_interval_seconds
        Config.config.get(:broker_client_default_async_poll_interval_seconds)
      end

      def default_polling_exponential_backoff
        Config.config.get(:broker_client_async_poll_exponential_backoff_rate)
      end

      def next_execution_in
        polling_interval_seconds * (default_polling_exponential_backoff**retry_number)
      end

      def next_enqueue_would_exceed_maximum_duration?
        Time.now + next_execution_in > start_time + maximum_duration_seconds
      end

      def finish
        @finished = true
      end

      def expire!
        handle_timeout if respond_to?(:handle_timeout)
        raise CloudController::Errors::ApiError.new_from_details('JobTimeout')
      end

      def enqueue_next_job(pollable_job)
        opts = {
          queue: Jobs::Queues.generic,
          run_at: Delayed::Job.db_time_now + next_execution_in
        }

        @retry_number += 1
        Jobs::Enqueuer.new(self, opts).enqueue_pollable(existing_guid: pollable_job.guid)
      end
    end
  end
end
