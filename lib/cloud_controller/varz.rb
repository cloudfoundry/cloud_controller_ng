require 'vcap/component'

module VCAP::CloudController
  class Varz
    def self.setup_updates
      VCAP::CloudController::Varz.bump_user_count
      VCAP::CloudController::Varz.bump_cc_job_queue_length
      VCAP::CloudController::Varz.record_thread_info

      EM.add_periodic_timer(VCAP::CloudController::Config.config[:varz_update_user_count_period_in_seconds] || 30) do
        VCAP::CloudController::Varz.bump_user_count
      end

      EM.add_periodic_timer(VCAP::CloudController::Config.config[:varz_update_cc_job_queue_length_in_seconds] || 30) do
        VCAP::CloudController::Varz.bump_cc_job_queue_length
      end

      EM.add_periodic_timer(VCAP::CloudController::Config.config[:varz_update_cc_record_thread_info] || 30) do
        VCAP::CloudController::Varz.record_thread_info
      end
    end

    def self.bump_user_count
      ::VCAP::Component.varz.synchronize do
        ::VCAP::Component.varz[:cc_user_count] = User.count
      end
    end

    def self.bump_cc_job_queue_length
      ::VCAP::Component.varz.synchronize do
        ::VCAP::Component.varz[:cc_job_queue_length] = pending_job_count_by_queue
      end
    end

    def self.record_thread_info
      ::VCAP::Component.varz.synchronize do
        ::VCAP::Component.varz[:thread_info] = thread_info
      end
    end

    private

    def self.pending_job_count_by_queue
      data = db[:delayed_jobs].where(attempts: 0).group_and_count(:queue)
      data.reduce({}) do |hash, row|
        hash[row[:queue].to_sym] = row[:count]
        hash
      end
    end

    def self.thread_info
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

    def self.db
      Sequel.synchronize { Sequel::DATABASES.first }
    end
  end
end
