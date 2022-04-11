require 'prometheus/client'

module VCAP::CloudController::Metrics
  class PrometheusUpdater
    def initialize(registry=Prometheus::Client.registry)
      @registry = registry
    end

    def update_gauge_metric(metric, value, message)
      unless @registry.exist?(metric)
        @registry.gauge(metric, docstring: message)
      end
      @registry.get(metric).set(value)
    end

    def increment_gauge_metric(metric, message)
      unless @registry.exist?(metric)
        @registry.gauge(metric, docstring: message)
      end
      @registry.get(metric).increment
    end

    def decrement_gauge_metric(metric, message)
      unless @registry.exist?(metric)
        @registry.gauge(metric, docstring: message)
      end
      @registry.get(metric).decrement
    end

    def increment_counter_metric(metric, message)
      unless @registry.exist?(metric)
        @registry.counter(metric, docstring: message)
      end
      @registry.get(metric).increment
    end

    def update_histogram_metric(metric, value, message, buckets)
      unless @registry.exist?(metric)
        @registry.histogram(metric, buckets: buckets, docstring: message)
      end
      @registry.get(metric).observe(value)
    end

    def update_summary_metric(metric, value, message)
      unless @registry.exist?(metric)
        @registry.summary(metric, docstring: message)
      end
      @registry.get(metric).observe(value)
    end

    def update_deploying_count(deploying_count)
      update_gauge_metric(:cc_deployments_deploying, deploying_count, 'Number of in progress deployments')
    end

    def update_user_count(user_count)
      update_gauge_metric(:cc_total_users, user_count, 'Number of users')
    end

    def update_job_queue_length(pending_job_count_by_queue, total)
      pending_job_count_by_queue.each do |key, value|
        metric_key = :"cc_job_queue_length_#{key.to_s.underscore}"
        update_gauge_metric(metric_key, value, docstring: "Job queue length for worker #{key}")
      end

      update_gauge_metric(:cc_job_queue_length_total, total, 'Total job queue length')
    end

    def update_thread_info(thread_info)
      update_gauge_metric(:cc_thread_info_thread_count, thread_info[:thread_count], 'Thread count')
      update_gauge_metric(:cc_thread_info_event_machine_connection_count, thread_info[:event_machine][:connection_count], 'Event Machine connection count')
      update_gauge_metric(:cc_thread_info_event_machine_threadqueue_size, thread_info[:event_machine][:threadqueue][:size], 'EventMachine thread queue size')
      update_gauge_metric(:cc_thread_info_event_machine_threadqueue_num_waiting, thread_info[:event_machine][:threadqueue][:num_waiting], 'EventMachine num waiting in thread')
      update_gauge_metric(:cc_thread_info_event_machine_resultqueue_size, thread_info[:event_machine][:resultqueue][:size], 'EventMachine queue size')
      update_gauge_metric(:cc_thread_info_event_machine_resultqueue_num_waiting, thread_info[:event_machine][:resultqueue][:num_waiting], 'EventMachine requests waiting in queue')
    end

    def update_failed_job_count(failed_jobs_by_queue, total)
      failed_jobs_by_queue.each do |key, value|
        metric_key = :"cc_failed_job_count_#{key.to_s.underscore}"
        update_gauge_metric(metric_key, value, "Failed jobs for worker #{key}")
      end

      update_gauge_metric(:cc_failed_job_count_total, total, 'Total failed jobs')
    end

    def update_vitals(vitals)
      vitals.each do |key, value|
        metric_key = :"cc_vitals_#{key.to_s.underscore}"
        update_gauge_metric(metric_key, value, "CloudController Vitals: #{key}")
      end
    end

    def update_log_counts(counts)
      counts.each do |key, value|
        metric_key = :"cc_log_count_#{key.to_s.underscore}"
        update_gauge_metric(metric_key, value, "Log count for log level '#{key}'")
      end
    end

    def update_task_stats(total_running_tasks, total_memory_in_mb)
      update_gauge_metric(:cc_tasks_running_count, total_running_tasks, 'Total running tasks')
      update_gauge_metric(:cc_tasks_running_memory_in_mb, total_memory_in_mb, 'Total memory consumed by running tasks')
    end

    def update_synced_invalid_lrps(lrp_count)
      update_gauge_metric(:cc_diego_sync_invalid_desired_lrps, lrp_count, 'Invalid Desired LRPs')
    end

    def start_staging_request_received
      increment_counter_metric(:cc_staging_requested, 'Number of staging requests')
    end

    def report_staging_success_metrics(duration_ns)
      increment_counter_metric(:cc_staging_succeeded, 'Number of successful staging events')
      update_histogram_metric(:cc_staging_succeeded_duration, nanoseconds_to_milliseconds(duration_ns), 'Durations of successful staging events', duration_buckets)
    end

    def report_staging_failure_metrics(duration_ns)
      increment_counter_metric(:cc_staging_failed, 'Number of failed staging events')
      update_histogram_metric(:cc_staging_failed_duration, nanoseconds_to_milliseconds(duration_ns), 'Durations of failed staging events', duration_buckets)
    end

    def report_diego_cell_sync_duration(duration_ms)
      update_summary_metric(:cc_diego_sync_duration, duration_ms, 'Diego cell sync duration')
      update_gauge_metric(:cc_diego_sync_duration_gauge, duration_ms, 'Diego cell sync duration (gauge metric)')
    end

    def report_deployment_duration(duration_ms)
      update_summary_metric(:cc_deployments_update_duration, duration_ms, 'Deployment duration')
      update_gauge_metric(:cc_deployments_update_duration_gauge, duration_ms, 'Deployment duration (gauge metric)')
    end

    private

    def duration_buckets
      Prometheus::Client::Histogram.linear_buckets(start: 10000, width: 5000, count: 5)
    end

    def nanoseconds_to_milliseconds(time_ns)
      (time_ns / 1e6).to_i
    end
  end
end
