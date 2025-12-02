module Vmstat
  # Implementation of performance metrics gathering for linux and other os with
  # the proc file system.
  module ProcFS
    # Grep from the man procfs about cpu data in stat file:
    # @example Format
    #     (num) user nice system idle iowait irq softirq steal
    # @example manpage
    #     iowait - time waiting for I/O to complete (since 2.5.41)  
    #     irq - time servicing interrupts (since 2.6.0-test4)
    #     softirq - time servicing softirqs (since 2.6.0-test4)
    #     Since Linux 2.6.11:
    #     steal - stolen time, which is the time spent in other operating 
    #             systems when running in a virtualized environment
    #     Since Linux 2.6.24:
    #     guest - which is the time spent running a virtual CPU for guest
    #             operating systems under the control of the Linux kernel.
    CPU_DATA = /cpu(\d+)#{'\s+(\d+)' * 4}/.freeze

    # Grep the network stats from the procfs.
    # @example Format (from /proc/net/dev)
    #   Inter-|   Receive                                                |  Transmit
    #    face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    # @example Data
    #   eth0:   33660     227    0    0    0     0          0         0    36584     167    0    0    0     0       0          0
    NET_DATA = /(\w+):#{'\s*(\d+)' * 16}/

    # Fetches the cpu statistics (usage counter for user, nice, system and idle)
    # @return [Array<Vmstat::Cpu>] the array of cpu counter
    # @example
    #   Vmstat.cpu # => [#<struct Vmstat::Cpu ...>, #<struct Vmstat::Cpu ...>]
    def cpu
      cpus = []
      procfs_file("stat") do |file|
        file.read.scan(CPU_DATA) do |i, user, nice, system, idle|
          cpus << Cpu.new(i.to_i, user.to_i, system.to_i, nice.to_i, idle.to_i)
        end
      end
      cpus
    end

    # Fetches the memory usage information.
    # @return [Vmstat::Memory] the memory data like free, used und total.
    # @example
    #   Vmstat.memory # => #<struct Vmstat::Memory ...>
    def memory
      @pagesize ||= Vmstat.pagesize
      has_available = false

      total = free = active = inactive = pageins = pageouts = available = 0
      procfs_file("meminfo") do |file|
        content = file.read(2048) # the requested information is in the first bytes

        content.scan(/(\w+):\s+(\d+) kB/) do |name, kbytes|
          pages = (kbytes.to_i * 1024) / @pagesize

          case name
            when "MemTotal" then total = pages
            when "MemFree" then free = pages
            when "MemAvailable"
                available = pages
                has_available = true
            when "Active" then active = pages
            when "Inactive" then inactive = pages
          end
        end
      end

      procfs_file("vmstat") do |file|
        content = file.read

        if content =~ /pgpgin\s+(\d+)/
          pageins = $1.to_i
        end

        if content =~ /pgpgout\s+(\d+)/
          pageouts = $1.to_i
        end
      end

      mem_klass = has_available ? LinuxMemory : Memory
      mem_klass.new(@pagesize, total-free-active-inactive, active,
                    inactive, free, pageins, pageouts).tap do |mem|
        mem.available = available if has_available
      end
    end

    # Fetches the information for all available network devices.
    # @return [Array<Vmstat::NetworkInterface>] the network device information
    # @example
    #   Vmstat.network_interfaces # => [#<struct Vmstat::NetworkInterface ...>, ...]
    def network_interfaces
      netifcs = []
      procfs_file("net", "dev") do |file|
        file.read.scan(NET_DATA) do |columns|
          type = case columns[0]
            when /^eth/ then NetworkInterface::ETHERNET_TYPE
            when /^lo/  then NetworkInterface::LOOPBACK_TYPE
          end

          netifcs << NetworkInterface.new(columns[0].to_sym, columns[1].to_i,
                                          columns[3].to_i,   columns[4].to_i,
                                          columns[9].to_i,   columns[11].to_i,
                                          type)
        end
      end
      netifcs
    end

    # Fetches the current process cpu and memory data.
    # @return [Vmstat::Task] the task data for the current process
    def task
      @pagesize ||= Vmstat.pagesize

      procfs_file("self", "stat") do |file|
        data = file.read.split(/ /)
        Task.new(data[22].to_i / @pagesize, data[23].to_i,
                 data[13].to_i * 1000, data[14].to_i * 1000)
      end
    end

    # Fetches the boot time of the system.
    # @return [Time] the boot time as regular time object.
    # @example
    #   Vmstat.boot_time # => 2012-10-09 18:42:37 +0200
    def boot_time
      raw = procfs_file("uptime") { |file| file.read }
      Time.now - raw.split(/\s/).first.to_f
    end

    # @return [String] the path to the proc file system
    # @example
    #   procfs_path # => "/proc"
    # @api private
    def procfs_path
      "/proc".freeze
    end

    # Opens a proc file system file handle and returns the handle in the
    # passed block. Closes the file handle.
    # @see File#open
    # @param [Array<String>] names parts of the path to the procfs file
    # @example
    #   procfs_file("net", "dev") { |file| }
    #   procfs_file("stat") { |file| }
    # @yieldparam [IO] file the file handle
    # @api private
    def procfs_file(*names, &block)
      path = File.join(procfs_path, *names)
      File.open(path, "r", &block)
    end
  end
end
