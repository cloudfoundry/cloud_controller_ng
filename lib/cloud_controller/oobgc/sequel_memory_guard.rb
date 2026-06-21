require 'sequel'

module Sequel
  module OobgcMemoryGuard
    # We define the methods in a module to allow prepending to Sequel::Database,
    # which is the modern idiomatic Ruby 3 alternative to alias_chain.
    
    OOBGC_THROTTLE_INTERVAL = 0.5 # half a second

    def log_connection_yield(sql, conn, args=nil, &block)
      check_oobgc_memory_pressure!
      super
    end

    private

    def check_oobgc_memory_pressure!
      rack_env = Thread.current[:rack_env]
      return unless rack_env && rack_env['oobgc.active']

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      last_check = rack_env['oobgc.last_check_time'] || 0.0

      if (now - last_check) < OOBGC_THROTTLE_INTERVAL
        return
      end
      
      rack_env['oobgc.last_check_time'] = now

      current_rss = read_rss_kb
      return unless current_rss

      if current_rss >= rack_env['oobgc.critical_threshold'] && !rack_env['oobgc.gc_enabled']
        rack_env['oobgc.gc_enabled'] = true
        GC.enable
        GC.start(full_mark: true, immediate_sweep: false)

        if defined?(Statsd) && Statsd.logger
          Statsd.logger.increment('oobgc.midflight.db_guard_triggered')
        end
      end
    end

    def read_rss_kb
      status_file = "/proc/#{Process.pid}/status"
      return nil unless File.exist?(status_file)

      File.read(status_file).each_line do |line|
        if line.start_with?('VmRSS:')
          return line.split[1].to_i
        end
      end
      nil
    rescue StandardError
      nil
    end
  end
end

# Register and apply the memory guard to the Sequel::Database class
Sequel::Database.prepend(Sequel::OobgcMemoryGuard)
