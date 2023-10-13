require 'prometheus/client'

module VCAP::CloudController::Metrics
  class PrometheusUpdater
    def initialize(registry=Prometheus::Client.registry)
      @registry = registry

      # Register all metrics, to initialize them for discoverability
      @registry.gauge(:cc_job_queues_length_total, docstring: 'Job queues length of worker processes', labels: [:queue]) unless @registry.exist?(:cc_job_queues_length_total)
      @registry.gauge(:cc_failed_jobs_total, docstring: 'Number of failed jobs of worker processes', labels: [:queue]) unless @registry.exist?(:cc_failed_jobs_total)
      @registry.counter(:cc_staging_requested, docstring: 'Number of staging requests') unless @registry.exist?(:cc_staging_requested)

      unless @registry.exist?(:cc_staging_succeeded_duration_seconds)
        @registry.histogram(:cc_staging_succeeded_duration_seconds,
                            docstring: 'Durations of successful staging events',
                            buckets: duration_buckets)
      end
      unless @registry.exist?(:cc_staging_failed_duration_seconds)
        @registry.histogram(:cc_staging_failed_duration_seconds,
                            docstring: 'Durations of failed staging events',
                            buckets: duration_buckets)
      end

      @registry.gauge(:cc_requests_outstanding_gauge, docstring: 'Requests Outstanding Gauge') unless @registry.exist?(:cc_requests_outstanding_gauge)
      @registry.counter(:cc_requests_completed, docstring: 'Requests Completed') unless @registry.exist?(:cc_requests_completed)
    end

    def update_gauge_metric(metric, value, message, labels: {})
      @registry.gauge(metric, docstring: message) unless @registry.exist?(metric)
      @registry.get(metric).set(value, labels:)
    end

    def increment_gauge_metric(metric, message)
      @registry.gauge(metric, docstring: message) unless @registry.exist?(metric)
      @registry.get(metric).increment
    end

    def decrement_gauge_metric(metric, message)
      @registry.gauge(metric, docstring: message) unless @registry.exist?(metric)
      @registry.get(metric).decrement
    end

    def increment_counter_metric(metric, message)
      @registry.counter(metric, docstring: message) unless @registry.exist?(metric)
      @registry.get(metric).increment
    end

    def update_histogram_metric(metric, value, message, buckets: nil)
      @registry.histogram(metric, buckets: buckets, docstring: message) unless @registry.exist?(metric)
      @registry.get(metric).observe(value)
    end

    def update_summary_metric(metric, value, message)
      @registry.summary(metric, docstring: message) unless @registry.exist?(metric)
      @registry.get(metric).observe(value)
    end

    def update_deploying_count(deploying_count)
      update_gauge_metric(:cc_deployments_deploying, deploying_count, 'Number of in progress deployments')
    end

    def update_user_count(user_count)
      update_gauge_metric(:cc_total_users, user_count, 'Number of users')
    end

    def update_job_queue_length(pending_job_count_by_queue)
      pending_job_count_by_queue.each do |key, value|
        update_gauge_metric(:cc_job_queues_length_total, value, "Job queue length for worker #{key}", labels: { queue: key.to_s.underscore })
      end
    end

    def update_thread_info(thread_info)
      update_gauge_metric(:cc_thread_info_thread_count, thread_info[:thread_count], 'Thread count')
      update_gauge_metric(:cc_thread_info_event_machine_connection_count, thread_info[:event_machine][:connection_count], 'Event Machine connection count')
      update_gauge_metric(:cc_thread_info_event_machine_threadqueue_size, thread_info[:event_machine][:threadqueue][:size], 'EventMachine thread queue size')
      update_gauge_metric(:cc_thread_info_event_machine_threadqueue_num_waiting, thread_info[:event_machine][:threadqueue][:num_waiting], 'EventMachine num waiting in thread')
      update_gauge_metric(:cc_thread_info_event_machine_resultqueue_size, thread_info[:event_machine][:resultqueue][:size], 'EventMachine queue size')
      update_gauge_metric(:cc_thread_info_event_machine_resultqueue_num_waiting, thread_info[:event_machine][:resultqueue][:num_waiting], 'EventMachine requests waiting in queue')
    end

    def update_failed_job_count(failed_jobs_by_queue)
      failed_jobs_by_queue.each do |key, value|
        update_gauge_metric(:cc_failed_jobs_total, value, "Failed jobs for worker #{key}", labels: { queue: key.to_s.underscore })
      end
    end

    def update_vitals(vitals)
      vitals.each do |key, value|
        next if key.to_s.underscore == 'cpu'

        metric_key = :"cc_vitals_#{key.to_s.underscore}"
        update_gauge_metric(metric_key, value, "CloudController Vitals: #{key}")
      end
    end

    def update_task_stats(total_running_tasks, total_memory_in_bytes)
      update_gauge_metric(:cc_tasks_running_count, total_running_tasks, 'Total running tasks')
      update_gauge_metric(:cc_tasks_running_memory_in_mb, total_memory_in_bytes, 'Total memory consumed by running tasks')
    end

    def start_staging_request_received
      increment_counter_metric(:cc_staging_requested, 'Number of staging requests')
    end

    def report_staging_success_metrics(duration_ns)
      update_histogram_metric(:cc_staging_succeeded_duration_seconds, nanoseconds_to_seconds(duration_ns), 'Durations of successful staging events')
    end

    def report_staging_failure_metrics(duration_ns)
      update_histogram_metric(:cc_staging_failed_duration_seconds, nanoseconds_to_seconds(duration_ns), 'Durations of failed staging events')
    end

    private

    def duration_buckets
      [5, 10, 30, 60, 300, 600, 890]
    end

    def nanoseconds_to_seconds(time_ns)
      (time_ns / 1e9).to_f
    end
  end
end
