module VCAP::CloudController
  class ProcessLogRateLimitCalculator
    attr_reader :process

    def initialize(process)
      @process = process
    end

    def additional_log_rate_limit_requested
      return 0 if process.stopped?
      return QuotaDefinition::UNLIMITED if is_process_log_rate_unlimited?

      total_requested_log_rate_limit - currently_used_log_rate_limit
    end

    def total_requested_log_rate_limit
      return 0 if process.log_rate_limit == QuotaDefinition::UNLIMITED

      process.log_rate_limit * process.instances
    end

    def currently_used_log_rate_limit
      return 0 if process.new?

      db_process = process_from_db
      return 0 if db_process.stopped? || db_process[:log_rate_limit] == QuotaDefinition::UNLIMITED

      db_process[:log_rate_limit] * db_process[:instances]
    end

    private

    def is_process_log_rate_unlimited?
      process.log_rate_limit == QuotaDefinition::UNLIMITED
    end

    def process_from_db
      error_message = 'Expected process record not found in database with guid %<guid>s'
      process_fetched_from_db = ProcessModel.find(guid: process.guid)
      if process_fetched_from_db.nil?
        logger.fatal('process.find.missing', guid: process.guid, self: process.inspect)
        raise CloudController::Errors::ApplicationMissing.new(sprintf(error_message, guid: process.guid))
      end
      process_fetched_from_db
    end

    def logger
      @logger ||= Steno.logger('cc.process_log_rate_limit_calculator')
    end
  end
end
