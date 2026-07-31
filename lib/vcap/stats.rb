require 'vcap/pid_file'

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
        return 0 unless linux?

        m = meminfo
        (m['MemTotal'] - m['Inactive'] - m['MemFree']) * 1024
      end

      def memory_free_bytes
        return 0 unless linux?

        m = meminfo
        (m['Inactive'] + m['MemFree']) * 1024
      end

      def cpu_load_average
        return 0 unless linux?

        File.read('/proc/loadavg').split.first.to_f
      end

      private

      def linux?
        RUBY_PLATFORM.match?(/linux/)
      end

      def meminfo
        File.read('/proc/meminfo').each_line.with_object({}) do |line, h|
          k, v = line.split
          h[k.chomp(':')] = v.to_i if k && v
        end
      end

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
