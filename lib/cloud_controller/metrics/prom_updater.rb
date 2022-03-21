module VCAP::CloudController::Metrics
  class PromUpdater
    def initialize(registry)
      @prom = registry
    end

    def record_user_count(user_count)
      @cc_total_users ||= @prom.gauge(:cc_total_users, docstring: 'A counter of total users')
      @cc_total_users.set(user_count)
    end

    def update_job_queue_length(pending_job_count_by_queue, total)
      pending_job_count_by_queue.each do |key, value|
        metric_key = :"cc_job_queue_length_#{key.to_s.underscore}"
        gauge = instance_variable_get(:"@#{metric_key}") || instance_variable_set(:"@#{metric_key}",
@prom.gauge(metric_key, docstring: "A counter of job queue length for worker #{key}"))
        gauge.set(value)
      end
      @cc_job_queue_length_total ||= @prom.gauge(:cc_job_queue_length_total, docstring: 'A counter for total job queue length')
      @cc_job_queue_length_total.set(total)
    end

    def update_deploying_count(deploying_count)
      return nil
      @prom.gauge(:cc_deployments_deploying, deploying_count)
    end

    def update_thread_info(thread_info)
      return nil
      @prom.gauge(:cc_thread_info_thread_count, thread_info[:thread_count])
      @prom.gauge(:cc_thread_info_event_machine_connection_count, thread_info[:event_machine][:connection_count])
      @prom.gauge(:cc_thread_info_event_machine_threadqueue_size, thread_info[:event_machine][:threadqueue][:size])
      @prom.gauge(:cc_thread_info_event_machine_threadqueue_num_waiting, thread_info[:event_machine][:threadqueue][:num_waiting])
      @prom.gauge(:cc_thread_info_event_machine_resultqueue_size, thread_info[:event_machine][:resultqueue][:size])
      @prom.gauge(:cc_thread_info_event_machine_resultqueue_num_waiting, thread_info[:event_machine][:resultqueue][:num_waiting])
    end

    def update_failed_job_count(failed_jobs_by_queue, total)
      return nil
      failed_job_count_by_queue.each do |key, value|
        @prom.gauge(:"cc_failed_job_count_#{key}", value)
      end
      @prom.gauge(:cc_failed_job_count_total, total)
    end

    def update_vitals(vitals)
      return nil
      vitals.each do |key, val|
        @prom.gauge(:"cc_vitals_#{key}", val)
      end
    end

    def update_log_counts(counts)
      return nil
      counts.each do |key, val|
        @prom.gauge(:"cc_log_count_#{key}", val)
      end
    end

    def update_task_stats(total_running_tasks, total_memory_in_mb)
      return nil
      @prom.gauge(:cc_tasks_running_count, total_running_tasks)
      @prom.gauge(:cc_tasks_running_memory_in_mb, total_memory_in_mb)
    end

    def update_synced_invalid_lrps(lrp_count)
      return nil
      @prom.gauge(:cc_diego_sync_invalid_desired_lrps, lrp_count)
    end

    def start_staging_request_received
      return nil
      @prom.counter(:cc_staging_requested).increment
    end

    def report_staging_success_metrics(duration_ns)
      return nil
      @prom.counter(:cc_staging_succeeded).increment
      # TODO: what is the prom equivalent
      # @statsd.timing('cc.staging.succeeded_duration', nanoseconds_to_milliseconds(duration_ns))
    end

    def report_staging_failure_metrics(duration_ns)
      return nil
      @prom.counter(:cc_staging_failed).increment
      # TODO: what is the prom equivalent for "timing"
      # @statsd.timing('cc_staging_failed_duration', nanoseconds_to_milliseconds(duration_ns))
    end
  end
end
