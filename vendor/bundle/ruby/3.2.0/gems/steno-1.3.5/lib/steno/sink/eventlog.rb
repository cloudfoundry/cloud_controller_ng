if Steno::Sink::WINDOWS
  require 'steno/sink/base'

  require 'singleton'
  require 'thread'
  require 'win32/eventlog'

  class Steno::Sink::Eventlog < Steno::Sink::Base
    include Singleton

    LOG_LEVEL_MAP = {
      fatal: Win32::EventLog::ERROR_TYPE,
      error: Win32::EventLog::ERROR_TYPE,
      warn: Win32::EventLog::WARN_TYPE,
      info: Win32::EventLog::INFO_TYPE,
      debug: Win32::EventLog::INFO_TYPE,
      debug1: Win32::EventLog::INFO_TYPE,
      debug2: Win32::EventLog::INFO_TYPE
    }

    def initialize
      super
      @eventlog = nil
    end

    def open
      @eventlog = Win32::EventLog.open('Application')
    end

    def add_record(record)
      msg = @codec.encode_record(record)
      pri = LOG_LEVEL_MAP[record.log_level]

      @eventlog.report_event(
        source: 'CloudFoundry',
        event_type: pri,
        data: msg
      )
    end

    def flush
      nil
    end
  end
end
