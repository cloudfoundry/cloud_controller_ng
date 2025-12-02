require 'thread'

require 'steno/codec'
require 'steno/config'
require 'steno/context'
require 'steno/errors'
require 'steno/log_level'
require 'steno/logger'
require 'steno/tagged_logger'
require 'steno/record'
require 'steno/sink'
require 'steno/version'

module Steno
  class << self
    attr_reader :config, :logger_regexp

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

      @logger_regexp = nil
      @logger_regexp_level = nil

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
          level = compute_level(name)

          logger = Steno::Logger.new(name, @config.sinks,
                                     level: level,
                                     context: @config.context)

          @loggers[name] = logger
        end

        logger
      end
    end

    # Sets all loggers whose name matches _regexp_ to _level_. Resets any
    # loggers whose name matches the previous regexp but not the supplied regexp.
    #
    # @param [Regexp] regexp
    # @param [Symbol] level
    #
    # @return [nil]
    def set_logger_regexp(regexp, level)
      @loggers_lock.synchronize do
        @loggers.each do |name, logger|
          if name =~ regexp
            logger.level = level
          elsif @logger_regexp && (name =~ @logger_regexp)
            # Reset loggers affected by the old regexp but not by the new
            logger.level = @config.default_log_level
          end
        end

        @logger_regexp = regexp
        @logger_regexp_level = level

        nil
      end
    end

    # Clears the logger regexp, if set. Resets the level of any loggers matching
    # the regex to the default log level.
    #
    # @return [nil]
    def clear_logger_regexp
      @loggers_lock.synchronize do
        return if @logger_regexp.nil?

        @loggers.each do |name, logger|
          logger.level = @config.default_log_level if name =~ @logger_regexp
        end

        @logger_regexp = nil
        @logger_regexp_level = nil
      end

      nil
    end

    # @return [Hash] Map of logger name => level
    def logger_level_snapshot
      @loggers_lock.synchronize do
        snapshot = {}

        @loggers.each { |name, logger| snapshot[name] = logger.level }

        snapshot
      end
    end

    private

    def compute_level(name)
      if @logger_regexp && name =~ @logger_regexp
        @logger_regexp_level
      else
        @config.default_log_level
      end
    end
  end
end

# Initialize with an empty config. All log records will swallowed until Steno
# is re-initialized with sinks.
Steno.init(Steno::Config.new)
