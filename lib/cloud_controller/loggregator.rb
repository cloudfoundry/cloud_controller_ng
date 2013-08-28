module VCAP::CloudController
  class Loggregator

    @@emitter = nil

    def self.emit(app_id, message)
      @@emitter.emit(app_id, message) if @@emitter
    end

    def self.emit_error(app_id, message)
      @@emitter.emit_error(app_id, message) if @@emitter
    end

    def self.emitter=(emitter)
      @@emitter = emitter
    end
  end
end
