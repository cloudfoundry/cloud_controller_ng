module VCAP::CloudController
  class DistributedExecutor
    def initialize
      @logger = Steno.logger('cc.clock')
    end

    def execute_job(name:, interval:, fudge:, timeout:)
      ensure_job_record_exists(name)

      need_to_run_job = nil
      job = nil

      ClockJob.db.transaction do
        job = ClockJob.find(name: name).lock!

        need_to_run_job = need_to_run_job?(job, interval, timeout, fudge)

        if need_to_run_job
          @logger.info("Queueing #{name} at #{now}")
          record_job_started(job)
        else
          message = "Skipping enqueue for #{name}. Job last started at #{job.last_started_at}, "
          message += "last completed at: #{job.last_completed_at}, interval: #{interval}, timeout: #{timeout}"
          @logger.info(message)
        end
      end

      if need_to_run_job
        begin
          yield
        ensure
          record_job_completed(job)
        end
      end
    end

    private

    def record_job_completed(job)
      job.reload
      job.update(last_completed_at: now)
    end

    def record_job_started(job)
      job.update(last_started_at: now)
    end

    def ensure_job_record_exists(job_name)
      ClockJob.find_or_create(name: job_name)
    rescue Sequel::UniqueConstraintViolation
      # find_or_create is not safe for concurrent access
    end

    def never_run?(job)
      job.last_started_at.nil?
    end

    def interval_elapsed?(job, interval, fudge)
      now >= (job.last_started_at + interval - fudge)
    end

    def job_in_progress?(job)
      if job.name == 'diego_sync'
        !(job.last_completed_at && (job.last_completed_at >= job.last_started_at))
      else
        Delayed::Job.where(queue: job.name, failed_at: nil).any?
      end
    end

    def need_to_run_job?(job, interval, timeout, fudge=0)
      return true if never_run?(job)
      return false if !interval_elapsed?(job, interval, fudge)
      return true if !job_in_progress?(job)

      if timeout.nil?
        timeout = Config.config.get(:jobs, :global, :timeout_in_seconds)
        if timeout.nil?
          return false
        end
      end
      interval_elapsed?(job, timeout, fudge)
    end

    def now
      Time.now.utc
    end
  end
end
