module VCAP::CloudController
  class ProcessMemoryCalculator
    attr_reader :process

    def initialize(process)
      @process = process
    end

    def additional_memory_requested
      return 0 if process.stopped?

      total_requested_memory - currently_used_memory
    end

    def total_requested_memory
      process.memory * process.instances
    end

    def currently_used_memory
      return 0 if process.new?

      db_process = process_from_db
      return 0 if db_process.stopped?

      db_process[:memory] * db_process[:instances]
    end

    private

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
      @logger ||= Steno.logger('cc.process_memory_calculator')
    end
  end
end
