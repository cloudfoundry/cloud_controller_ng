require 'fluent-logger'

module VCAP
  class FluentEmitter
    class Error < StandardError; end
    SOURCE_TYPE = 'API'.freeze
    PRIMARY_TAG = 'API'.freeze

    attr_reader :fluent_logger

    def initialize(fluent_logger)
      @fluent_logger = fluent_logger
    end

    def emit(app_id, message)
      unless fluent_logger.post(PRIMARY_TAG, message(app_id, message))
        raise Error.new(fluent_logger.last_error)
      end
    end

    private

    def message(app_id, message)
      {
        app_id: app_id,
        log: message,
        source_type: SOURCE_TYPE,
        instance_id: '0', # TODO: fill this from an environment variable?
      }
    end
  end
end
