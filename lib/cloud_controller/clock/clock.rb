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
        name: name,
        interval: 1.day,
        at: at,
        fudge: DAILY_FUDGE_FACTOR
      }

      schedule_job(job_opts) do
        job = yield
        Jobs::Enqueuer.new(queue: name, priority: priority).enqueue(job)
      end
    end

    def schedule_frequent_worker_job(name:, interval:)
      job_opts = {
        name: name,
        interval: interval,
        fudge: FREQUENT_FUDGE_FACTOR
      }

      schedule_job(job_opts) do
        job = yield
        Jobs::Enqueuer.new(queue: name).enqueue(job)
      end
    end

    def schedule_frequent_inline_job(name:, interval:, timeout:)
      job_opts = {
        name: name,
        interval: interval,
        fudge: FREQUENT_FUDGE_FACTOR,
        thread: true,
        timeout: timeout
      }

      schedule_job(job_opts) do
        job = yield
        Jobs::Enqueuer.new(queue: name).run_inline(job)
      end
    end

    private

    def schedule_job(job_opts, &)
      DistributedScheduler.new.schedule_periodic_job(**job_opts, &)
    end
  end
end
