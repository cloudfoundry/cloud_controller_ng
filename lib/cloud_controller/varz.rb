require 'vcap/component'

module VCAP::CloudController
  class Varz
    def self.setup_updates
      record_user_count
      update_job_queue_length
      update_thread_info

      EM.add_periodic_timer(config[:varz_update_user_count_period_in_seconds] || 600) do
        record_user_count
      end

      EM.add_periodic_timer(config[:varz_update_cc_job_queue_length_in_seconds] || 30) do
        update_job_queue_length
      end

      EM.add_periodic_timer(config[:varz_update_cc_record_thread_info] || 30) do
        update_thread_info
      end
    end

    def self.record_user_count
      user_count = User.count

      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:cc_user_count] = user_count }
    end

    def self.update_job_queue_length
      pending_job_count_by_queue = get_pending_job_count_by_queue

      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:cc_job_queue_length] = pending_job_count_by_queue }
    end

    def self.update_thread_info
      thread_info = get_thread_info

      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:thread_info] = thread_info }
    end

    private

    def self.config
      VCAP::CloudController::Config.config
    end

    def self.get_pending_job_count_by_queue
      jobs_by_queue_with_count = Delayed::Job.where(attempts: 0).group_and_count(:queue)

      jobs_by_queue_with_count.reduce({}) do |hash, row|
        hash[row[:queue].to_sym] = row[:count]
        hash
      end
    end

    def self.get_thread_info
      threadqueue = EM.instance_variable_get(:@threadqueue)
      resultqueue = EM.instance_variable_get(:@resultqueue)
      {
        thread_count: Thread.list.size,
        event_machine: {
          connection_count: EventMachine.connection_count,
          threadqueue: {
            size: threadqueue ? threadqueue.size : 0,
            num_waiting: threadqueue ? threadqueue.num_waiting : 0,
          },
          resultqueue: {
            size: resultqueue ? resultqueue.size : 0,
            num_waiting: resultqueue ? resultqueue.num_waiting : 0,
          },
        },
      }
    end
  end
end
