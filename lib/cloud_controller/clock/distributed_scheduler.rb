require 'clockwork'

module VCAP::CloudController
  class DistributedScheduler
    def initialize
      @logger = Steno.logger('cc.clock')
    end

    def schedule_periodic_job(name:, interval:, at: nil, thread: nil, fudge:)
      ensure_job_record_exists(name)

      clock_opts      = {}
      clock_opts[:at] = at if at
      clock_opts[:thread] = thread if thread

      Clockwork.every(interval, "#{name}.job", clock_opts) do |_|
        need_to_run_job = false

        ClockJob.db.transaction do
          job = ClockJob.find(name: name).lock!

          need_to_run_job = need_to_run_job?(job, interval, fudge)

          if need_to_run_job
            @logger.info("Queueing #{name} at #{now}")
            record_job_started(job)
          end
        end

        if need_to_run_job
          yield
        end
      end
    end

    def record_job_started(job)
      job.update(last_started_at: now)
    end

    def ensure_job_record_exists(job_name)
      ClockJob.find_or_create(name: job_name)
    rescue Sequel::UniqueConstraintViolation
      # find_or_create is not safe for concurrent access
    end

    def need_to_run_job?(job, interval, fudge=0)
      if job.last_started_at.nil?
        return true
      end
      now >= (job.last_started_at + interval - fudge)
    end

    def now
      Time.now.utc
    end
  end
end
