module Vmstat
  module Solaris
    module ClassMethods
      def cpu
        kstat = `kstat -p "cpu_stat:::/idle|kernel|user/"`
        cpus = Hash.new { |h, k| h[k] = Hash.new }

        kstat.lines.each do |line|
          _, cpu, _, key, value = line.strip.split(/:|\s+/)
          cpus[cpu.to_i][key] = value
        end

        cpus.map do |num, v|
          Cpu.new(num, v["user"].to_i, v["kernel"].to_i, 0, v["idle"].to_i)
        end
      end

      def boot_time
        Time.at(`kstat -p unix:::boot_time`.strip.split(/\s+/).last.to_i)
      end

      def memory
        kstat = `kstat -p -n system_pages`
        values = Hash.new

        kstat.lines.each do |line|
          _, _, _, key, value = line.strip.split(/:|\s+/)
          values[key] = value
        end

        total = values['pagestotal'].to_i
        free = values['pagesfree'].to_i
        locked = values['pageslocked'].to_i

        Memory.new(Vmstat.pagesize,
                   locked, # wired
                   total - free - locked, # active
                   0, # inactive
                   free, # free
                   0, #pageins
                   0) #pageouts
      end

      def network_interfaces
        kstat = `kstat -p link:::`
        itfs = Hash.new { |h, k| h[k] = Hash.new }

        kstat.lines.each do |line|
          _, _, name, key, value = line.strip.split(/:|\s+/)
          itfs[name.to_sym][key] = value
        end

        itfs.map do |k, v|
          NetworkInterface.new(k, v['rbytes64'].to_i,
                                  v['ierrors'].to_i,
                                  0,
                                  v['obytes64'].to_i,
                                  v['oerrors'].to_i,
                                  NetworkInterface::ETHERNET_TYPE)
        end
      end
    end

    extend ClassMethods

    def self.included base
      base.instance_eval do
        def cpu; Vmstat::Solaris.cpu end
        def boot_time; Vmstat::Solaris.boot_time end
        def memory; Vmstat::Solaris.memory end
        def network_interfaces; Vmstat::Solaris.network_interfaces end
      end
    end
  end
end
