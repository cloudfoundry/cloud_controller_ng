require 'statsd'

module VCAP::CloudController::Metrics
  class StatsdUpdater
    def initialize(statsd=Statsd.new)
      @statsd = statsd
    end

    def record_user_count(user_count)
      @statsd.gauge('cc.total_users', user_count)
    end

    def update_job_queue_length(pending_job_count_by_queue, total)
      @statsd.batch do |batch|
        pending_job_count_by_queue.each do |key, value|
          batch.gauge("cc.job_queue_length.#{key}", value)
        end
        batch.gauge('cc.job_queue_length.total', total)
      end
    end

    def update_thread_info(thread_info)
      @statsd.batch do |batch|
        batch.gauge('cc.thread_info.thread_count', thread_info[:thread_count])
        batch.gauge('cc.thread_info.event_machine.connection_count', thread_info[:event_machine][:connection_count])
        batch.gauge('cc.thread_info.event_machine.threadqueue.size', thread_info[:event_machine][:threadqueue][:size])
        batch.gauge('cc.thread_info.event_machine.threadqueue.num_waiting', thread_info[:event_machine][:threadqueue][:num_waiting])
        batch.gauge('cc.thread_info.event_machine.resultqueue.size', thread_info[:event_machine][:resultqueue][:size])
        batch.gauge('cc.thread_info.event_machine.resultqueue.num_waiting', thread_info[:event_machine][:resultqueue][:num_waiting])
      end
    end

    def update_failed_job_count(failed_jobs_by_queue, total)
      @statsd.batch do |batch|
        failed_jobs_by_queue.each do |key, value|
          batch.gauge("cc.failed_job_count.#{key}", value)
        end
        batch.gauge('cc.failed_job_count.total', total)
      end
    end

    def update_vitals(vitals)
      @statsd.batch do |batch|
        batch.gauge('cc.vitals.uptime', vitals[:uptime])
        batch.gauge('cc.vitals.cpu_load_avg', vitals[:cpu_load_avg])
        batch.gauge('cc.vitals.mem_used_bytes', vitals[:mem_used_bytes])
        batch.gauge('cc.vitals.mem_free_bytes', vitals[:mem_free_bytes])
        batch.gauge('cc.vitals.mem_bytes', vitals[:mem_bytes])
        batch.gauge('cc.vitals.cpu', vitals[:cpu])
      end
    end
  end
end
