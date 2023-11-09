require 'prometheus/client'

module VCAP::CloudController::Metrics
  class PrometheusUpdater
    def initialize(registry=Prometheus::Client.registry)
      @registry = registry

      # Register all metrics, to initialize them for discoverability
      metrics.map do |metric|
        register_metric(metric[:type], metric[:name], metric[:docstring], labels: metric[:labels] || {}, buckets: metric[:buckets] || {}) unless @registry.exist?(metric[:name])
      end
    end

    def register_metric(type, name, message, labels: {}, buckets: {})
      case type
      when :gauge
        @registry.gauge(name, docstring: message, labels: labels)
      when :counter
        @registry.counter(name, docstring: message, labels: labels)
      when :histogram
        @registry.histogram(name, docstring: message, labels: labels, buckets: buckets)
      else
        throw ArgumentError("Metric type #{type} does not exist.")
      end
    end

    def update_gauge_metric(metric, value, labels: {})
      @registry.get(metric).set(value, labels:)
    end

    def increment_gauge_metric(metric)
      @registry.get(metric).increment
    end

    def decrement_gauge_metric(metric)
      @registry.get(metric).decrement
    end

    def increment_counter_metric(metric)
      @registry.get(metric).increment
    end

    def update_histogram_metric(metric, value)
      @registry.get(metric).observe(value)
    end

    def update_summary_metric(metric, value)
      @registry.get(metric).observe(value)
    end

    def update_deploying_count(deploying_count)
      update_gauge_metric(:cc_deployments_in_progress_total, deploying_count)
    end

    def update_user_count(user_count)
      update_gauge_metric(:cc_users_total, user_count)
    end

    def update_job_queue_length(pending_job_count_by_queue)
      pending_job_count_by_queue.each do |key, value|
        update_gauge_metric(:cc_job_queues_length_total, value, labels: { queue: key.to_s.underscore })
      end
    end

    def update_thread_info(thread_info)
      update_gauge_metric(:cc_thread_info_thread_count, thread_info[:thread_count])
      update_gauge_metric(:cc_thread_info_event_machine_connection_count, thread_info[:event_machine][:connection_count])
      update_gauge_metric(:cc_thread_info_event_machine_threadqueue_size, thread_info[:event_machine][:threadqueue][:size])
      update_gauge_metric(:cc_thread_info_event_machine_threadqueue_num_waiting, thread_info[:event_machine][:threadqueue][:num_waiting])
      update_gauge_metric(:cc_thread_info_event_machine_resultqueue_size, thread_info[:event_machine][:resultqueue][:size])
      update_gauge_metric(:cc_thread_info_event_machine_resultqueue_num_waiting, thread_info[:event_machine][:resultqueue][:num_waiting])
    end

    def update_failed_job_count(failed_jobs_by_queue)
      failed_jobs_by_queue.each do |key, value|
        update_gauge_metric(:cc_failed_jobs_total, value, labels: { queue: key.to_s.underscore })
      end
    end

    def update_vitals(vitals)
      vitals.each do |key, value|
        metric_key = :"cc_vitals_#{key.to_s.underscore}"
        update_gauge_metric(metric_key, value)
      end
    end

    def update_task_stats(total_running_tasks, total_memory_in_bytes)
      update_gauge_metric(:cc_running_tasks_total, total_running_tasks)
      update_gauge_metric(:cc_running_tasks_memory_bytes, total_memory_in_bytes)
    end

    def start_staging_request_received
      increment_counter_metric(:cc_staging_requested_total)
    end

    def report_staging_success_metrics(duration_ns)
      update_histogram_metric(:cc_staging_succeeded_duration_seconds, nanoseconds_to_seconds(duration_ns))
    end

    def report_staging_failure_metrics(duration_ns)
      update_histogram_metric(:cc_staging_failed_duration_seconds, nanoseconds_to_seconds(duration_ns))
    end

    private

    def metrics
      [
        { type: :gauge, name: :cc_job_queues_length_total, docstring: 'Job queues length of worker processes', labels: [:queue] },
        { type: :gauge, name: :cc_failed_jobs_total, docstring: 'Number of failed jobs of worker processes', labels: [:queue] },
        { type: :counter, name: :cc_staging_requested_total, docstring: 'Number of staging requests' },
        { type: :histogram, name: :cc_staging_succeeded_duration_seconds, docstring: 'Durations of successful staging events', buckets: duration_buckets },
        { type: :histogram, name: :cc_staging_failed_duration_seconds, docstring: 'Durations of failed staging events', buckets: duration_buckets },
        { type: :gauge, name: :cc_requests_outstanding_total, docstring: 'Requests outstanding' },
        { type: :counter, name: :cc_requests_completed_total, docstring: 'Requests completed' },
        { type: :gauge, name: :cc_thread_info_thread_count, docstring: 'Thread count' },
        { type: :gauge, name: :cc_thread_info_event_machine_connection_count, docstring: 'Event Machine connection count' },
        { type: :gauge, name: :cc_thread_info_event_machine_threadqueue_size, docstring: 'EventMachine thread queue size' },
        { type: :gauge, name: :cc_thread_info_event_machine_threadqueue_num_waiting, docstring: 'EventMachine num waiting in thread' },
        { type: :gauge, name: :cc_thread_info_event_machine_resultqueue_size, docstring: 'EventMachine queue size' },
        { type: :gauge, name: :cc_thread_info_event_machine_resultqueue_num_waiting, docstring: 'EventMachine requests waiting in queue' },
        { type: :gauge, name: :cc_vitals_started_at, docstring: 'CloudController Vitals: started_at' },
        { type: :gauge, name: :cc_vitals_mem_bytes, docstring: 'CloudController Vitals: mem_bytes' },
        { type: :gauge, name: :cc_vitals_cpu_load_avg, docstring: 'CloudController Vitals: cpu_load_avg' },
        { type: :gauge, name: :cc_vitals_mem_used_bytes, docstring: 'CloudController Vitals: mem_used_bytes' },
        { type: :gauge, name: :cc_vitals_mem_free_bytes, docstring: 'CloudController Vitals: mem_free_bytes' },
        { type: :gauge, name: :cc_vitals_num_cores, docstring: 'CloudController Vitals: num_cores' },
        { type: :gauge, name: :cc_running_tasks_total, docstring: 'Total running tasks' },
        { type: :gauge, name: :cc_running_tasks_memory_bytes, docstring: 'Total memory consumed by running tasks' },
        { type: :gauge, name: :cc_users_total, docstring: 'Number of users' },
        { type: :gauge, name: :cc_deployments_in_progress_total, docstring: 'Number of in progress deployments' }
      ]
    end

    def duration_buckets
      [5, 10, 30, 60, 300, 600, 890]
    end

    def nanoseconds_to_seconds(time_ns)
      (time_ns / 1e9).to_f
    end
  end
end
