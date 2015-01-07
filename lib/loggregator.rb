class Loggregator
  class << self
    attr_accessor :emitter

    def emit(app_id, message)
      emitter.emit(app_id, message) if emitter
    end

    def emit_error(app_id, message)
      emitter.emit_error(app_id, message) if emitter
    end
  end
end
