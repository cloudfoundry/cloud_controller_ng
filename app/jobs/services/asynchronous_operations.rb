module VCAP::CloudController
  module Jobs
    module Services
      module AsynchronousOperations
        private

        def new_end_timestamp
          Time.now + Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes
        end

        def retry_job(retry_after_header: '')
          update_polling_interval(retry_after_header: retry_after_header)
          if Time.now + poll_interval > end_timestamp
            end_timestamp_reached
          else
            enqueue_again
          end
        end

        def enqueue_again
          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now + poll_interval }
          Jobs::Enqueuer.new(self, opts).enqueue
        end

        def update_polling_interval(retry_after_header: '')
          default_poll_interval = Config.config.get(:broker_client_default_async_poll_interval_seconds)
          poll_interval = [default_poll_interval, retry_after_header.to_i].max
          self.poll_interval = [poll_interval, 24.hours].min
        end
      end
    end
  end
end
