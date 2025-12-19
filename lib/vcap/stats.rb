require 'vcap/pid_file'
require 'vmstat'

module VCAP
  class Stats
    class << self
      def process_memory_bytes_and_cpu
        rss = []
        pcpu = []

        ps_out = ps_pid
        ps_out += ps_ppid if is_puma_webserver?
        ps_out.split.each_with_index { |e, i| i.even? ? rss << e : pcpu << e }

        [rss.map(&:to_i).sum * 1024, pcpu.map(&:to_f).sum.round]
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

      private

      def ps_pid
        `ps -o rss=,pcpu= -p #{Process.pid}`
      end

      def ps_ppid
        if RUBY_PLATFORM.match?(/darwin/)
          `ps ax -o ppid,rss,pcpu | awk '$1 == #{Process.pid} { print $2,$3 }'`
        else
          `ps -o rss=,pcpu= --ppid #{Process.pid}`
        end
      end

      def is_puma_webserver?
        VCAP::CloudController::Config.config.get(:webserver) == 'puma'
      rescue VCAP::CloudController::Config::InvalidConfigPath
        false
      end
    end
  end
end
