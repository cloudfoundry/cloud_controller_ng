module LogHelpers
  class TailedLogs
    def initialize(io_log)
      @io_log = io_log
    end

    def read
      @io_log.string.split("\n").map { |l| Oj.load(l) }
    end
  end

  def tail_logs(&block)
    steno_config_backup = ::Steno.config

    begin
      io_log = ::StringIO.new
      io_sink = ::Steno::Sink::IO.new(io_log, codec: ::Steno::Codec::JsonRFC3339.new)
      ::Steno.init(::Steno::Config.new(
                     sinks: steno_config_backup.sinks + [io_sink],
                     codec: steno_config_backup.codec,
                     context: steno_config_backup.context,
                     default_log_level: 'all'
                   ))

      block.yield(TailedLogs.new(io_log))
    ensure
      ::Steno.init(steno_config_backup)
    end
  end
end
