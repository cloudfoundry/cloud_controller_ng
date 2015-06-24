require 'cloud_controller/metrics/varz_updater'
require 'cloud_controller/metrics/statsd_updater'

module VCAP::CloudController::Metrics
  class PeriodicUpdater
    def initialize(start_time, log_counter, updaters=[VarzUpdater.new, StatsdUpdater.new])
      @start_time = start_time
      @updaters    = updaters
      @log_counter = log_counter
    end

    def setup_updates
      update!
      EM.add_periodic_timer(600) { record_user_count }
      EM.add_periodic_timer(30) { update_job_queue_length }
      EM.add_periodic_timer(30) { update_thread_info }
      EM.add_periodic_timer(30) { update_failed_job_count }
      EM.add_periodic_timer(30) { update_vitals }
      EM.add_periodic_timer(30) { update_log_counts }
    end

    def update!
      record_user_count
      update_job_queue_length
      update_thread_info
      update_failed_job_count
      update_vitals
      update_log_counts
    end

    def update_log_counts
      counts = @log_counter.counts

      hash = {}
      Steno::Logger::LEVELS.keys.each do |level_name|
        hash[level_name] = counts.fetch(level_name.to_s, 0)
      end

      @updaters.each { |u| u.update_log_counts(hash) }
    end

    def record_user_count
      user_count = VCAP::CloudController::User.count

      @updaters.each { |u| u.record_user_count(user_count) }
    end

    def update_job_queue_length
      jobs_by_queue_with_count = Delayed::Job.where(attempts: 0).group_and_count(:queue)

      total                      = 0
      pending_job_count_by_queue = jobs_by_queue_with_count.each_with_object({}) do |row, hash|
        total                    += row[:count]
        hash[row[:queue].to_sym] = row[:count]
      end

      @updaters.each { |u| u.update_job_queue_length(pending_job_count_by_queue, total) }
    end

    def update_thread_info
      local_thread_info = thread_info

      @updaters.each { |u| u.update_thread_info(local_thread_info) }
    end

    def update_failed_job_count
      jobs_by_queue_with_count = Delayed::Job.where('failed_at IS NOT NULL').group_and_count(:queue)

      total                = 0
      failed_jobs_by_queue = jobs_by_queue_with_count.each_with_object({}) do |row, hash|
        total                    += row[:count]
        hash[row[:queue].to_sym] = row[:count]
      end

      @updaters.each { |u| u.update_failed_job_count(failed_jobs_by_queue, total) }
    end

    def update_vitals
      rss_bytes, pcpu = VCAP::Stats.process_memory_bytes_and_cpu

      vitals = {
        uptime:         Time.now.utc.to_i - @start_time.to_i,
        cpu:            pcpu.to_f,
        mem_bytes:      rss_bytes.to_i,
        cpu_load_avg:   VCAP::Stats.cpu_load_average,
        mem_used_bytes: VCAP::Stats.memory_used_bytes,
        mem_free_bytes: VCAP::Stats.memory_free_bytes,
        num_cores:      VCAP.num_cores,
      }

      @updaters.each { |u| u.update_vitals(vitals) }
    end

    def thread_info
      threadqueue = EM.instance_variable_get(:@threadqueue) || []
      resultqueue = EM.instance_variable_get(:@resultqueue) || []
      {
        thread_count:  Thread.list.size,
        event_machine: {
          connection_count: EventMachine.connection_count,
          threadqueue:      {
            size:        threadqueue.size,
            num_waiting: threadqueue.is_a?(Array) ? 0 : threadqueue.num_waiting,
          },
          resultqueue:      {
            size:        resultqueue.size,
            num_waiting: resultqueue.is_a?(Array) ? 0 : resultqueue.num_waiting,
          },
        },
      }
    end
  end
end
