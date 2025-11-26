require 'cloud_controller/metrics/statsd_updater'
require 'vcap/stats'

module VCAP::CloudController::Metrics
  class PeriodicUpdater
    def initialize(start_time, log_counter, logger, statsd_updater, prometheus_updater)
      @start_time = start_time
      @statsd_updater = statsd_updater
      @prometheus_updater = prometheus_updater
      @log_counter = log_counter
      @logger = logger
      @known_job_queues = {
        VCAP::CloudController::Jobs::Queues.local(VCAP::CloudController::Config.config).to_sym => 0
      }
    end

    def setup_updates
      update!
      @update_tasks = []
      @update_tasks << Concurrent::TimerTask.new(execution_interval: 600) { catch_error { update_user_count } }.execute
      @update_tasks << Concurrent::TimerTask.new(execution_interval: 30) { catch_error { update_job_queue_length } }.execute
      @update_tasks << Concurrent::TimerTask.new(execution_interval: 30) { catch_error { update_job_queue_load } }.execute
      @update_tasks << Concurrent::TimerTask.new(execution_interval: 30) { catch_error { update_failed_job_count } }.execute
      @update_tasks << Concurrent::TimerTask.new(execution_interval: 30) { catch_error { update_vitals } }.execute
      @update_tasks << Concurrent::TimerTask.new(execution_interval: 30) { catch_error { update_log_counts } }.execute
      @update_tasks << Concurrent::TimerTask.new(execution_interval: 30) { catch_error { update_task_stats } }.execute
      @update_tasks << Concurrent::TimerTask.new(execution_interval: 30) { catch_error { update_deploying_count } }.execute
      @update_tasks << Concurrent::TimerTask.new(execution_interval: 30) { catch_error { update_webserver_stats } }.execute
    end

    def stop_updates
      return unless @update_tasks

      @update_tasks.each(&:shutdown)
    end

    def update!
      update_user_count
      update_job_queue_length
      update_job_queue_load
      update_failed_job_count
      update_vitals
      update_log_counts
      update_task_stats
      update_deploying_count
      update_webserver_stats
    end

    def catch_error
      yield
    rescue StandardError => e
      @logger.info(e)
    end

    def update_task_stats
      running_tasks = VCAP::CloudController::TaskModel.where(state: VCAP::CloudController::TaskModel::RUNNING_STATE)
      running_task_count = running_tasks.count
      running_task_memory = running_tasks.sum(:memory_in_mb) || 0
      @statsd_updater.update_task_stats(running_task_count, running_task_memory)
      @prometheus_updater.update_task_stats(running_task_count, running_task_memory * 1024 * 1024)
    end

    def update_log_counts
      counts = @log_counter.counts

      hash = {}
      Steno::Logger::LEVELS.each_key do |level_name|
        hash[level_name] = counts.fetch(level_name.to_s, 0)
      end

      @statsd_updater.update_log_counts(hash)
    end

    def update_deploying_count
      deploying_count = VCAP::CloudController::DeploymentModel.deploying_count

      [@statsd_updater, @prometheus_updater].each { |u| u.update_deploying_count(deploying_count) }
    end

    def update_user_count
      user_count = VCAP::CloudController::User.count

      [@statsd_updater, @prometheus_updater].each { |u| u.update_user_count(user_count) }
    end

    def update_job_queue_length
      jobs_by_queue_with_count = Delayed::Job.where(attempts: 0).group_and_count(:queue)

      total                      = 0
      pending_job_count_by_queue = jobs_by_queue_with_count.each_with_object({}) do |row, hash|
        @known_job_queues[row[:queue].to_sym] = 0
        total += row[:count]
        hash[row[:queue].to_sym] = row[:count]
      end

      pending_job_count_by_queue.reverse_merge!(@known_job_queues)
      @statsd_updater.update_job_queue_length(pending_job_count_by_queue, total)
      @prometheus_updater.update_job_queue_length(pending_job_count_by_queue)
    end

    def update_job_queue_load
      jobs_by_queue_with_run_now = Delayed::Job.
                                   where(Sequel.lit('run_at <= ?', Time.now)).
                                   where(Sequel.lit('failed_at IS NULL')).group_and_count(:queue)

      total = 0
      pending_job_load_by_queue = jobs_by_queue_with_run_now.each_with_object({}) do |row, hash|
        @known_job_queues[row[:queue].to_sym] = 0
        total += row[:count]
        hash[row[:queue].to_sym] = row[:count]
      end

      pending_job_load_by_queue.reverse_merge!(@known_job_queues)
      @statsd_updater.update_job_queue_load(pending_job_load_by_queue, total)
      @prometheus_updater.update_job_queue_load(pending_job_load_by_queue)
    end

    def update_failed_job_count
      jobs_by_queue_with_count = Delayed::Job.where(Sequel.lit('failed_at IS NOT NULL')).group_and_count(:queue)

      total                = 0
      failed_jobs_by_queue = jobs_by_queue_with_count.each_with_object({}) do |row, hash|
        @known_job_queues[row[:queue].to_sym] = 0
        total += row[:count]
        hash[row[:queue].to_sym] = row[:count]
      end

      failed_jobs_by_queue.reverse_merge!(@known_job_queues)
      @statsd_updater.update_failed_job_count(failed_jobs_by_queue, total)
      @prometheus_updater.update_failed_job_count(failed_jobs_by_queue)
    end

    def update_vitals
      rss_bytes, pcpu = VCAP::Stats.process_memory_bytes_and_cpu

      vitals = {
        uptime: Time.now.utc.to_i - @start_time.to_i,
        cpu: pcpu.to_f,
        mem_bytes: rss_bytes.to_i,
        cpu_load_avg: VCAP::Stats.cpu_load_average,
        mem_used_bytes: VCAP::Stats.memory_used_bytes,
        mem_free_bytes: VCAP::Stats.memory_free_bytes,
        num_cores: VCAP::HostSystem.new.num_cores
      }

      @statsd_updater.update_vitals(vitals)

      prom_vitals = vitals.clone
      prom_vitals.delete(:uptime)
      prom_vitals.delete(:cpu)
      prom_vitals[:started_at] = @start_time.to_i
      @prometheus_updater.update_vitals(prom_vitals)
    end

    def update_webserver_stats
      return unless VCAP::CloudController::Config.config.get(:webserver) == 'puma'

      local_stats = Puma.stats_hash
      worker_count = local_stats[:booted_workers]
      worker_stats = local_stats[:worker_status].map do |worker_status|
        {
          started_at: Time.parse(worker_status[:started_at]).utc.to_i,
          index: worker_status[:index],
          pid: worker_status[:pid],
          thread_count: worker_status[:last_status][:running],
          backlog: worker_status[:last_status][:backlog],
          pool_capacity: worker_status[:last_status][:pool_capacity],
          busy_threads: worker_status[:last_status][:busy_threads],
          requests_count: worker_status[:last_status][:requests_count]
        }
      end
      @prometheus_updater.update_webserver_stats_puma(worker_count, worker_stats)
    end
  end
end
