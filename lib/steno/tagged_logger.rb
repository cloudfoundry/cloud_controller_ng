require 'steno/logger'

module Steno
end

# Provides a proxy that allows persistent user data
class Steno::TaggedLogger
  attr_reader :proxied_logger
  attr_accessor :user_data

  class << self
    # The following helpers are used to create a new scope for binding the log
    # level.

    def define_log_method(name)
      define_method(name) { |*args, &blk| log(name, *args, &blk) }
    end

    def define_logf_method(name)
      define_method("#{name}f") { |fmt, *args| log(name, fmt % args) }
    end
  end

  Steno::Logger::LEVELS.each_key do |name|
    # Define #debug, for example
    define_log_method(name)

    # Define #debugf, for example
    define_logf_method(name)
  end

  def initialize(proxied_logger, user_data={})
    @proxied_logger = proxied_logger
    @user_data = user_data
  end

  def method_missing(method, ...)
    @proxied_logger.send(method, ...)
  end

  def respond_to_missing?(method, include_private=false)
    @proxied_logger.respond_to?(method, include_private) || super
  end

  # @see Steno::Logger#log
  def log(level_name, message=nil, user_data=nil, &)
    ud = @user_data.merge(user_data || {})

    @proxied_logger.log(level_name, message, ud, &)
  end

  # @see Steno::Logger#log_exception
  def log_exception(exception, user_data={})
    ud = @user_data.merge(user_data || {})

    @proxied_logger.log_exception(exception, ud)
  end

  def tag(new_user_data={})
    Steno::TaggedLogger.new(proxied_logger, user_data.merge(new_user_data))
  end
end
