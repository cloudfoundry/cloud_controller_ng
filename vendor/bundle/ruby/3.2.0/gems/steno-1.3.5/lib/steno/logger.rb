require 'thread'

require 'steno/errors'
require 'steno/log_level'

module Steno
end

class Steno::Logger
  LEVELS = {
    off: Steno::LogLevel.new(:off, 0),
    fatal: Steno::LogLevel.new(:fatal,   1),
    error: Steno::LogLevel.new(:error,   5),
    warn: Steno::LogLevel.new(:warn,   10),
    info: Steno::LogLevel.new(:info,   15),
    debug: Steno::LogLevel.new(:debug, 16),
    debug1: Steno::LogLevel.new(:debug1, 17),
    debug2: Steno::LogLevel.new(:debug2, 18),
    all: Steno::LogLevel.new(:all, 30)
  }

  class << self
    # The following helpers are used to create a new scope for binding the log
    # level.

    def define_log_method(name)
      define_method(name) { |*args, &blk| log(name, *args, &blk) }
    end

    def define_logf_method(name)
      define_method(name.to_s + 'f') { |fmt, *args| log(name, fmt % args) }
    end

    def define_level_active_predicate(name)
      define_method(name.to_s + '?') { level_active?(name) }
    end

    def lookup_level(name)
      level = LEVELS[name]

      raise Steno::Error.new("Unknown level: #{name}") if level.nil?

      level
    end
  end

  # This is magic, however, it's vastly simpler than declaring each method
  # manually.
  LEVELS.each do |name, _|
    # Define #debug, for example
    define_log_method(name)

    # Define #debugf, for example
    define_logf_method(name)

    # Define #debug?, for example. These are provided to ensure compatibility
    # with Ruby's standard library Logger class.
    define_level_active_predicate(name)
  end

  attr_reader :name

  # @param [String] name The logger name.
  # @param [Array<Steno::Sink::Base>] sinks
  # @param [Hash] opts
  # @option opts [Symbol] :level  The minimum level for which this logger will
  #         emit log records. Defaults to :info.
  # @option opts [Steno::Context] :context
  def initialize(name, sinks, opts = {})
    @name           = name
    @min_level      = self.class.lookup_level(opts[:level] || :info)
    @min_level_lock = Mutex.new
    @sinks          = sinks
    @context        = opts[:context] || Steno::Context::Null.new
  end

  # Sets the minimum level for which records will be added to sinks.
  #
  # @param [Symbol] level_name  The level name
  #
  # @return [nil]
  def level=(level_name)
    level = self.class.lookup_level(level_name)

    @min_level_lock.synchronize { @min_level = level }
  end

  # Returns the name of the current log level
  #
  # @return [Symbol]
  def level
    @min_level_lock.synchronize { @min_level.name }
  end

  # Returns whether or not records for the given level would be forwarded to
  # sinks.
  #
  # @param [Symbol] level_name
  #
  # @return [true || false]
  def level_active?(level_name)
    level = self.class.lookup_level(level_name)
    @min_level_lock.synchronize { level <= @min_level }
  end

  # Convenience method for logging an exception, along with its backtrace.
  #
  # @param [Exception] ex

  # @return [nil]
  def log_exception(ex, user_data = {})
    warn("Caught exception: #{ex}", user_data.merge(backtrace: ex.backtrace))
  end

  # Adds a record to the configured sinks.
  #
  # @param [Symbol] level_name    The level associated with the record
  # @param [String] message
  # @param [Hash] user_data
  #
  # @return [nil]
  def log(level_name, message = nil, user_data = nil)
    return unless level_active?(level_name)

    message = yield if block_given?

    callstack = caller
    loc = parse_record_loc(callstack)

    data = @context.data.merge(user_data || {})

    record = Steno::Record.new(@name, level_name, message, loc, data)

    @sinks.each { |sink| sink.add_record(record) }

    nil
  end

  # Returns a proxy that will emit the supplied user data along with each
  # log record.
  #
  # @param [Hash] user_data
  #
  # @return [Steno::TaggedLogger]
  def tag(user_data = {})
    Steno::TaggedLogger.new(self, user_data)
  end

  private

  def parse_record_loc(callstack)
    file = nil
    lineno = nil
    method = nil

    callstack.each do |frame|
      next if frame =~ /logger\.rb/

      file, lineno, method = frame.split(':')

      lineno = lineno.to_i

      method = ::Regexp.last_match(1) if method =~ /in `([^']+)/

      break
    end

    [file, lineno, method]
  end
end
