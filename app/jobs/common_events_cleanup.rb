module VCAP::CloudController
  class CommonEventsCleanUp < VCAP::CloudController::Jobs::CCJob
    attr_accessor :cutoff_age_in_days
    attr_accessor :event_model
    attr_accessor :job_name

    def perform
      CommonEventsCleanUp.delete_model_events_older_than(@event_model, cutoff_age_in_days)
    end

    def job_name_in_configuration
      @job_name
    end

    def max_attempts
      1
    end

    def self.delete_model_events_older_than(model, cutoff_age_in_days)
      old_events = if model.db.database_type == :mssql
                     model.dataset.where('CREATED_AT < DATEADD(DAY, -?, CURRENT_TIMESTAMP)', cutoff_age_in_days.to_i)
                   else
                     model.dataset.where("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", cutoff_age_in_days.to_i)
                   end
      logger = Steno.logger('cc.background')
      logger.info("Cleaning up #{old_events.count} event rows")
      old_events.delete
    end
  end
end
