class Loggregator
  class << self
    attr_accessor :emitter, :logger

    def emit(app_id, message)
      emitter.emit(app_id, message) if emitter
    rescue => e
      logger.error('loggregator_emitter.emit.failed', app_id: app_id, message: message, error: e)
    end

    def emit_error(app_id, message)
      emitter.emit_error(app_id, message) if emitter
    rescue => e
      logger.error('loggregator_emitter.emit_error.failed', app_id: app_id, message: message, error: e)
    end
  end
end
