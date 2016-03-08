require 'vcap/component'

module VCAP::CloudController::Metrics
  class VarzUpdater
    def record_user_count(user_count)
      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:cc_user_count] = user_count }
    end

    def update_job_queue_length(pending_job_count_by_queue, total)
      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:cc_job_queue_length] = pending_job_count_by_queue }
      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:cc_job_queue_length][:total] = total }
    end

    def update_thread_info(thread_info)
      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:thread_info] = thread_info }
    end

    def update_failed_job_count(failed_jobs_by_queue, total)
      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:cc_failed_job_count] = failed_jobs_by_queue }
      ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:cc_failed_job_count][:total] = total }
    end

    def update_vitals(_)
      # noop
    end

    def update_log_counts(_)
      # noop
    end

    def update_task_stats(_, _)
      # noop
    end
  end
end
