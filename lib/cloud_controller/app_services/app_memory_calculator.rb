module VCAP::CloudController
  class AppMemoryCalculator
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def additional_memory_requested
      return 0 if app.stopped?
      total_requested_memory - currently_used_memory
    end

    def total_requested_memory
      app.memory * app.instances
    end

    def currently_used_memory
      return 0 if app.new?
      db_app = app_from_db
      return 0 if db_app.stopped?
      db_app[:memory] * db_app[:instances]
    end

    private

    def app_from_db
      error_message = 'Expected app record not found in database with guid %s'
      app_from_db   = App.find(guid: app.guid)
      if app_from_db.nil?
        logger.fatal('app.find.missing', guid: app.guid, self: app.inspect)
        raise Errors::ApplicationMissing.new(error_message % app.guid)
      end
      app_from_db
    end

    def logger
      @logger ||= Steno.logger('cc.app_memory_calculator')
    end
  end
end
