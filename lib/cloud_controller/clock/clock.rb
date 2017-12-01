require 'clockwork'
require 'cloud_controller/clock/distributed_scheduler'

module VCAP::CloudController
  class Clock
    FREQUENT_FUDGE_FACTOR = 1.second.freeze
    DAILY_FUDGE_FACTOR    = 1.minute.freeze

    HIGH_PRIORITY   = 0
    MEDIUM_PRIORITY = 1
    LOW_PRIORITY    = 100

    def schedule_daily_job(name:, at:, priority:)
      job_opts = {
        name:     name,
        interval: 1.day,
        at:       at,
        fudge:    DAILY_FUDGE_FACTOR,
      }

      schedule_job(job_opts) do
        job = yield
        Jobs::Enqueuer.new(job, queue: 'cc-generic', priority: priority).enqueue
      end
    end

    def schedule_frequent_worker_job(name:, interval:)
      job_opts = {
        name:     name,
        interval: interval,
        fudge:    FREQUENT_FUDGE_FACTOR,
      }

      schedule_job(job_opts) do
        job = yield
        Jobs::Enqueuer.new(job, queue: 'cc-generic').enqueue
      end
    end

    def schedule_frequent_inline_job(name:, interval:, timeout:)
      job_opts = {
        name:     name,
        interval: interval,
        fudge:    FREQUENT_FUDGE_FACTOR,
        thread:   true,
        timeout:  timeout,
      }

      schedule_job(job_opts) do
        job = yield
        Jobs::Enqueuer.new(job).run_inline
      end
    end

    private

    def schedule_job(job_opts)
      DistributedScheduler.new.schedule_periodic_job(job_opts) { yield }
    end
  end
end
