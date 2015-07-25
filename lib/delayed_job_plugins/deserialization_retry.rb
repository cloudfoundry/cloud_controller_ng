class DeserializationRetry < Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.around(:failure) do |job, *args, &block|
      db_job = args[0]

      if expired?(db_job)
        block.call(job, *args)
      else
        reschedule(db_job)
        clear_lock(db_job)
        db_job.save
      end
    end
  end

  class << self
    def expired?(job)
      job.created_at < Delayed::Job.db_time_now - 24.hours
    end

    def reschedule(job)
      job.run_at = Delayed::Job.db_time_now + 5.minutes
    end

    def clear_lock(job)
      job.locked_by = nil
      job.locked_at = nil
    end
  end
end
