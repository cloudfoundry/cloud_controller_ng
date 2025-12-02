module Vmstat
  # This is a stub module that should be replaced by system specific
  # implementations of the different functions. This can either be native or
  # with other modules like {ProcFS}.
  module Stub
    # Fetches the boot time of the system.
    # @return [Time] the boot time as regular time object.
    # @example
    #   Vmstat.boot_time # => 2012-10-09 18:42:37 +0200
    def self.boot_time
      nil
    end

    # Fetches the cpu statistics (usage counter for user, nice, system and idle)
    # @return [Array<Vmstat::Cpu>] the array of cpu counter
    # @example
    #   Vmstat.cpu # => [#<struct Vmstat::Cpu ...>, #<struct Vmstat::Cpu ...>]
    def self.cpu
      []
    end

    # Fetches the usage data and other useful disk information for the given path.
    # @param [String] path the path (mount point or device path) to the disk
    # @return [Vmstat::Disk] the disk information
    # @example
    #   Vmstat.disk("/") # => #<struct Vmstat::Disk type=:hfs, ...>
    def self.disk(path)
      nil
    end

    # Fetches the load average for the current system.
    # @return [Vmstat::LoadAverage] the load average data
    # @example
    #   Vmstat.load_average # => #<struct Vmstat::LoadAverage one_minute=...>
    def self.load_average
      nil
    end

    # Fetches the memory usage information.
    # @return [Vmstat::Memory] the memory data like free, used und total.
    # @example
    #   Vmstat.memory # => #<struct Vmstat::Memory ...>
    def self.memory
      nil
    end

    # Fetches the information for all available network devices.
    # @return [Array<Vmstat::NetworkInterface>] the network device information
    # @example
    #   Vmstat.network_interfaces # => [#<struct Vmstat::NetworkInterface ...>, ...]
    def self.network_interfaces
      []
    end

    # Fetches pagesize of the current system.
    # @return [Fixnum] the pagesize of the current system in bytes.
    # @example
    #   Vmstat.pagesize # => 4096
    def self.pagesize
      4096
    end

    # Fetches time and memory usage for the current process.
    # @note Currently only on Mac OS X
    # @return [Array<Vmstat::Task>] the network device information
    # @example
    #   Vmstat.task # => #<struct Vmstat::Task ...>
    def self.task
      nil
    end
  end
end
