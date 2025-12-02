require 'yaml'

require 'steno/codec'
require 'steno/context'
require 'steno/logger'
require 'steno/sink'

module Steno
end

class Steno::Config
  class << self
    # Creates a config given a yaml file of the following form:
    #
    #     logging:
    #       level:  <info, debug, etc>
    #       file:   </path/to/logfile>
    #       syslog: <syslog name>
    #
    # @param [String] path  Path to yaml config
    # @param [Hash] overrides
    #
    # @return [Steno::Config]
    def from_file(path, overrides = {})
      h = YAML.load_file(path)
      h = h['logging'] || {}
      new(to_config_hash(h).merge(overrides))
    end

    def from_hash(hash)
      new(to_config_hash(hash))
    end

    def to_config_hash(hash)
      hash ||= {}
      hash = symbolize_keys(hash)

      level = hash[:level] || hash[:default_log_level]
      opts = {
        sinks: [],
        default_log_level: level.nil? ? :info : level.to_sym
      }

      opts[:codec] = Steno::Codec::Json.new(iso8601_timestamps: true) if hash[:iso8601_timestamps]

      if hash[:file]
        max_retries = hash[:max_retries]
        opts[:sinks] << Steno::Sink::IO.for_file(hash[:file], max_retries: max_retries)
      end

      if Steno::Sink::WINDOWS
        if hash[:eventlog]
          Steno::Sink::Eventlog.instance.open(hash[:eventlog])
          opts[:sinks] << Steno::Sink::Eventlog.instance
        end
      elsif hash[:syslog]
        Steno::Sink::Syslog.instance.open(hash[:syslog])
        opts[:sinks] << Steno::Sink::Syslog.instance
      end

      opts[:sinks] << Steno::Sink::Fluentd.new(hash[:fluentd]) if hash[:fluentd]

      opts[:sinks] << Steno::Sink::IO.new(STDOUT) if opts[:sinks].empty?

      opts
    end

    def symbolize_keys(hash)
      Hash[hash.each_pair.map { |k, v| [k.to_sym, v] }]
    end
  end

  attr_reader :sinks, :codec, :context, :default_log_level

  def initialize(opts = {})
    @sinks             = opts[:sinks] || []
    @codec             = opts[:codec] || Steno::Codec::Json.new
    @context           = opts[:context] || Steno::Context::Null.new

    @sinks.each { |sink| sink.codec = @codec }

    @default_log_level = if opts[:default_log_level]
                           opts[:default_log_level].to_sym
                         else
                           :info
                         end
  end

  private_class_method :symbolize_keys
end
