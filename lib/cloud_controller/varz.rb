require 'vcap/component'

module VCAP::CloudController
  class Varz
    def self.setup_updates
      update!
      EM.add_periodic_timer(600) { record_user_count }
      EM.add_periodic_timer(30) { update_job_queue_length }
      EM.add_periodic_timer(30) { update_thread_info }
    end

    def self.record_user_count
      user_count = User.count

      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:cc_user_count] = user_count }
    end

    def self.update_job_queue_length
      local_pending_job_count_by_queue = pending_job_count_by_queue

      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:cc_job_queue_length] = local_pending_job_count_by_queue }
    end

    def self.update_thread_info
      local_thread_info = thread_info

      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:thread_info] = local_thread_info }
    end

    def self.update!
      record_user_count
      update_job_queue_length
      update_thread_info
    end

    def self.pending_job_count_by_queue
      jobs_by_queue_with_count = Delayed::Job.where(attempts: 0).group_and_count(:queue)

      jobs_by_queue_with_count.each_with_object({}) do |row, hash|
        hash[row[:queue].to_sym] = row[:count]
      end
    end

    def self.thread_info
      threadqueue = EM.instance_variable_get(:@threadqueue) || []
      resultqueue = EM.instance_variable_get(:@resultqueue) || []
      {
        thread_count: Thread.list.size,
        event_machine: {
          connection_count: EventMachine.connection_count,
          threadqueue: {
            size: threadqueue.size,
            num_waiting: threadqueue.is_a?(Array) ? 0 : threadqueue.num_waiting,
          },
          resultqueue: {
            size: resultqueue.size,
            num_waiting: resultqueue.is_a?(Array) ? 0 : resultqueue.num_waiting,
          },
        },
      }
    end
  end
end
