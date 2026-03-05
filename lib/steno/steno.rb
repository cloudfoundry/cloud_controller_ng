require 'steno/codec'
require 'steno/config'
require 'steno/context'
require 'steno/errors'
require 'steno/log_level'
require 'steno/logger_io'
require 'steno/logger'
require 'steno/record'
require 'steno/sink'

module Steno
  class << self
    attr_reader :config

    # Initializes the logging system. This must be called exactly once before
    # attempting to use any Steno class methods.
    #
    # @param [Steno::Config]
    #
    # @return [nil]
    def init(config)
      @config = config

      @loggers = {}
      @loggers_lock = Mutex.new

      nil
    end

    # Returns (and memoizes) the logger identified by name.
    #
    # @param [String] name
    #
    # @return [Steno::Logger]
    def logger(name)
      @loggers_lock.synchronize do
        logger = @loggers[name]

        if logger.nil?
          logger = Steno::Logger.new(name, @config.sinks,
                                     level: @config.default_log_level,
                                     context: @config.context)

          @loggers[name] = logger
        end

        logger
      end
    end
  end
end

# Initialize with an empty config. All log records will swallowed until Steno
# is re-initialized with sinks.
Steno.init(Steno::Config.new)
