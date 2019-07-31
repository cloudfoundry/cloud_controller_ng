require 'vcap/pid_file'
require 'vmstat'

module VCAP
  class Stats
    class << self
      def process_memory_bytes_and_cpu
        rss, pcpu = `ps -o rss=,pcpu= -p #{Process.pid}`.split.map(&:to_i)
        rss_bytes = rss * 1024
        [rss_bytes, pcpu]
      end

      def memory_used_bytes
        mem = Vmstat.memory
        mem.active_bytes + mem.wired_bytes
      end

      def memory_free_bytes
        mem = Vmstat.memory
        mem.inactive_bytes + mem.free_bytes
      end

      def cpu_load_average
        Vmstat.load_average.one_minute
      end
    end
  end
end
