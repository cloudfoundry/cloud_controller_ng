require 'prometheus/client'
require 'prometheus/client/data_stores/direct_file_store'
require 'cloud_controller/execution_context'

module VCAP::CloudController::Metrics
  class PrometheusUpdater
    # We want to label worker metrics with the worker's pid. By default, this label is reserved
    # within the Prometheus::Client, thus we modify the BASE_RESERVED_LABELS constant.
    # Nevertheless, the pid label should be used with caution, i.e. only for metrics that are
    # aggregated and thus don't have the pid label set automatically!
    def self.allow_pid_label
      return unless Prometheus::Client::LabelSetValidator.const_get(:BASE_RESERVED_LABELS).include?(:pid)

      reserved_labels = Prometheus::Client::LabelSetValidator.const_get(:BASE_RESERVED_LABELS).dup
      reserved_labels.delete_if { |l| l == :pid }
      Prometheus::Client::LabelSetValidator.send(:remove_const, :BASE_RESERVED_LABELS)
      Prometheus::Client::LabelSetValidator.const_set(:BASE_RESERVED_LABELS, reserved_labels.freeze)
    end

    DURATION_BUCKETS = [5, 10, 30, 60, 300, 600, 890].freeze
    CONNECTION_DURATION_BUCKETS = [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5, 10].freeze
    DELAYED_JOB_METRIC_BUCKETS = [0.01, 0.05, 0.1, 0.5, 1, 2, 5, 10, 30, 60, 120, 300, 600].freeze

    METRICS = [
      { type: :gauge, name: :cc_job_queues_length_total, docstring: 'Job queues length of worker processes', labels: [:queue], aggregation: :most_recent },
      { type: :gauge, name: :cc_job_queues_load_total, docstring: 'Number of background jobs ready to run now ', labels: [:queue], aggregation: :most_recent },
      { type: :gauge, name: :cc_failed_jobs_total, docstring: 'Number of failed jobs of worker processes', labels: [:queue], aggregation: :most_recent },
      { type: :counter, name: :cc_staging_requests_total, docstring: 'Number of staging requests' },
      { type: :histogram, name: :cc_staging_succeeded_duration_seconds, docstring: 'Durations of successful staging events', buckets: DURATION_BUCKETS },
      { type: :histogram, name: :cc_staging_failed_duration_seconds, docstring: 'Durations of failed staging events', buckets: DURATION_BUCKETS },
      { type: :gauge, name: :cc_requests_outstanding_total, docstring: 'Requests outstanding', aggregation: :sum },
      { type: :counter, name: :cc_requests_completed_total, docstring: 'Requests completed' },
      { type: :gauge, name: :cc_running_tasks_total, docstring: 'Total running tasks', aggregation: :most_recent },
      { type: :gauge, name: :cc_running_tasks_memory_bytes, docstring: 'Total memory consumed by running tasks', aggregation: :most_recent },
      { type: :gauge, name: :cc_users_total, docstring: 'Number of users', aggregation: :most_recent },
      { type: :gauge, name: :cc_deployments_in_progress_total, docstring: 'Number of in progress deployments', aggregation: :most_recent },
      { type: :histogram, name: :cc_app_usage_snapshot_generation_duration_seconds, docstring: 'Time taken to generate app usage snapshots', buckets: DELAYED_JOB_METRIC_BUCKETS },
      { type: :counter, name: :cc_app_usage_snapshot_generation_failures_total, docstring: 'Total number of failed app usage snapshot generations' },
      { type: :histogram, name: :cc_service_usage_snapshot_generation_duration_seconds, docstring: 'Time taken to generate service usage snapshots',
        buckets: DELAYED_JOB_METRIC_BUCKETS },
      { type: :counter, name: :cc_service_usage_snapshot_generation_failures_total, docstring: 'Total number of failed service snapshot generations' }
    ].freeze

    PUMA_METRICS = [
      { type: :gauge, name: :cc_puma_worker_count, docstring: 'Puma worker count', aggregation: :most_recent },
      { type: :gauge, name: :cc_puma_worker_started_at, docstring: 'Puma worker: started_at', labels: %i[index pid], aggregation: :most_recent },
      { type: :gauge, name: :cc_puma_worker_thread_count, docstring: 'Puma worker: thread count', labels: %i[index pid], aggregation: :most_recent },
      { type: :gauge, name: :cc_puma_worker_backlog, docstring: 'Puma worker: backlog', labels: %i[index pid], aggregation: :most_recent },
      { type: :gauge, name: :cc_puma_worker_pool_capacity, docstring: 'Puma worker: pool capacity', labels: %i[index pid], aggregation: :most_recent },
      { type: :gauge, name: :cc_puma_worker_requests_count, docstring: 'Puma worker: requests count', labels: %i[index pid], aggregation: :most_recent },
      { type: :gauge, name: :cc_puma_worker_busy_threads, docstring: 'Puma worker: busy threads', labels: %i[index pid], aggregation: :most_recent }
    ].freeze

    DB_CONNECTION_POOL_METRICS = [
      { type: :gauge, name: :cc_acquired_db_connections_total, labels: %i[process_type], docstring: 'Number of acquired DB connections' },
      { type: :histogram, name: :cc_db_connection_hold_duration_seconds, docstring: 'The time threads were holding DB connections',
        buckets: CONNECTION_DURATION_BUCKETS },
      # cc_connection_pool_timeouts_total must be a gauge metric, because otherwise we cannot match them with processes
      { type: :gauge, name: :cc_db_connection_pool_timeouts_total, labels: %i[process_type],
        docstring: 'Number of threads which failed to acquire a free DB connection from the pool within the timeout' },
      { type: :gauge, name: :cc_open_db_connections_total, labels: %i[process_type], docstring: 'Number of open DB connections (acquired + available)' },
      { type: :histogram, name: :cc_db_connection_wait_duration_seconds, docstring: 'The time threads were waiting for an available DB connection',
        buckets: CONNECTION_DURATION_BUCKETS }
    ].freeze

    DELAYED_JOB_METRICS = [
      { type: :histogram, name: :cc_job_pickup_delay_seconds, docstring: 'Job pickup time (from enqueue to start)', labels: %i[queue worker], buckets: DELAYED_JOB_METRIC_BUCKETS },
      { type: :histogram, name: :cc_job_duration_seconds, docstring: 'Job processing time (start to finish)', labels: %i[queue worker], buckets: DELAYED_JOB_METRIC_BUCKETS }
    ].freeze

    VITAL_METRICS = [
      { type: :gauge, name: :cc_vitals_started_at, docstring: 'CloudController Vitals: started_at', aggregation: :most_recent },
      { type: :gauge, name: :cc_vitals_mem_bytes, docstring: 'CloudController Vitals: mem_bytes', aggregation: :most_recent },
      { type: :gauge, name: :cc_vitals_cpu_load_avg, docstring: 'CloudController Vitals: cpu_load_avg', aggregation: :most_recent },
      { type: :gauge, name: :cc_vitals_mem_used_bytes, docstring: 'CloudController Vitals: mem_used_bytes', aggregation: :most_recent },
      { type: :gauge, name: :cc_vitals_mem_free_bytes, docstring: 'CloudController Vitals: mem_free_bytes', aggregation: :most_recent },
      { type: :gauge, name: :cc_vitals_num_cores, docstring: 'CloudController Vitals: num_cores', aggregation: :most_recent }
    ].freeze

    def initialize(registry: Prometheus::Client.registry)
      self.class.allow_pid_label

      @registry = registry
      @execution_context = VCAP::CloudController::ExecutionContext.from_process_type_env

      register_metrics_for_process
      return if @execution_context.nil? # In unit tests, the execution context might not be set - thus skip initialization

      initialize_cc_db_connection_pool_timeouts_total
    end

    private

    # rubocop:disable Metrics/CyclomaticComplexity
    def register_metrics_for_process
      case @execution_context
      when VCAP::CloudController::ExecutionContext::CC_WORKER
        DB_CONNECTION_POOL_METRICS.each { |metric| register(metric) }
        DELAYED_JOB_METRICS.each { |metric| register(metric) }
        VITAL_METRICS.each { |metric| register(metric) }
      when VCAP::CloudController::ExecutionContext::CLOCK, VCAP::CloudController::ExecutionContext::DEPLOYMENT_UPDATER
        DB_CONNECTION_POOL_METRICS.each { |metric| register(metric) }
        VITAL_METRICS.each { |metric| register(metric) }
      when VCAP::CloudController::ExecutionContext::API_PUMA_MAIN, VCAP::CloudController::ExecutionContext::API_PUMA_WORKER
        DB_CONNECTION_POOL_METRICS.each { |metric| register(metric) }
        DELAYED_JOB_METRICS.each { |metric| register(metric) }
        VITAL_METRICS.each { |metric| register(metric) }
        METRICS.each { |metric| register(metric) }
        PUMA_METRICS.each { |metric| register(metric) }
      else
        raise "Could not register Prometheus metrics: Unexpected execution context: #{@execution_context.inspect}"
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def initialize_cc_db_connection_pool_timeouts_total
      return unless @registry.exist?(:cc_db_connection_pool_timeouts_total) # If the metric is not registered, we don't need to initialize it

      # initialize metric with 0 for discoverability, because it likely won't get updated on healthy systems
      update_gauge_metric(:cc_db_connection_pool_timeouts_total, 0, labels: { process_type: @execution_context.process_type })
      # also initialize for puma_worker
      return unless @execution_context == VCAP::CloudController::ExecutionContext::API_PUMA_MAIN

      update_gauge_metric(:cc_db_connection_pool_timeouts_total, 0,
                          labels: { process_type: VCAP::CloudController::ExecutionContext::API_PUMA_WORKER.process_type })
    end

    public

    def update_gauge_metric(metric, value, labels: {})
      @registry.get(metric).set(value, labels:)
    end

    def increment_gauge_metric(metric, labels: {})
      @registry.get(metric).increment(labels:)
    end

    def decrement_gauge_metric(metric, labels: {})
      @registry.get(metric).decrement(labels:)
    end

    def increment_counter_metric(metric)
      @registry.get(metric).increment
    end

    def update_histogram_metric(metric, value, labels: {})
      @registry.get(metric).observe(value, labels:)
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

    def update_job_queue_load(update_job_queue_load)
      update_job_queue_load.each do |key, value|
        update_gauge_metric(:cc_job_queues_load_total, value, labels: { queue: key.to_s.underscore })
      end
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

    def update_webserver_stats_puma(worker_count, worker_stats)
      update_gauge_metric(:cc_puma_worker_count, worker_count)

      worker_stats.each do |stats|
        index = stats.delete(:index)
        pid = stats.delete(:pid)

        stats.each do |key, value|
          metric_key = :"cc_puma_worker_#{key.to_s.underscore}"
          update_gauge_metric(metric_key, value, labels: { index:, pid: })
        end
      end
    end

    def start_staging_request_received
      increment_counter_metric(:cc_staging_requests_total)
    end

    def report_staging_success_metrics(duration_ns)
      update_histogram_metric(:cc_staging_succeeded_duration_seconds, nanoseconds_to_seconds(duration_ns))
    end

    def report_staging_failure_metrics(duration_ns)
      update_histogram_metric(:cc_staging_failed_duration_seconds, nanoseconds_to_seconds(duration_ns))
    end

    private

    def register(metric)
      return if @registry.exist?(metric[:name])

      register_metric(metric[:type], metric[:name], metric[:docstring], labels: metric[:labels] || [], buckets: metric[:buckets] || [], aggregation: metric[:aggregation])
    end

    def register_metric(type, name, message, labels:, buckets:, aggregation:)
      store_settings = {}
      store_settings[:aggregation] = aggregation if aggregation.present? && Prometheus::Client.config.data_store.instance_of?(Prometheus::Client::DataStores::DirectFileStore)

      case type
      when :gauge
        @registry.gauge(name, docstring: message, labels: labels, store_settings: store_settings)
      when :counter
        @registry.counter(name, docstring: message, labels: labels, store_settings: store_settings)
      when :histogram
        @registry.histogram(name, docstring: message, labels: labels, buckets: buckets, store_settings: store_settings)
      else
        throw ArgumentError("Metric type #{type} does not exist.")
      end
    end

    def nanoseconds_to_seconds(time_ns)
      (time_ns / 1e9).to_f
    end
  end
end
