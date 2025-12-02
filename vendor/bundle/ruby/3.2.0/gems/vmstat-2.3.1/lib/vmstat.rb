require "vmstat/version"

# This is a focused and fast library to get system information like:
# 
# * _Memory_ (free, active, ...)
# * _Network_ _Interfaces_ (name, in bytes, out bytes, ...)
# * _CPU_ (user, system, nice, idle)
# * _Load_ Average
# * _Disk_ (type, disk path, free bytes, total bytes, ...)
# * _Boot_ _Time_
# * _Current_ _Task_ (used bytes and usage time *MACOSX* or *LINUX* *ONLY*)
module Vmstat
  autoload :Cpu,              "vmstat/cpu"
  autoload :NetworkInterface, "vmstat/network_interface"
  autoload :Disk,             "vmstat/disk"
  autoload :LinuxDisk,        "vmstat/linux_disk"
  autoload :Memory,           "vmstat/memory"
  autoload :LinuxMemory,      "vmstat/linux_memory"
  autoload :Task,             "vmstat/task"
  autoload :LoadAverage,      "vmstat/load_average"
  autoload :ProcFS,           "vmstat/procfs"
  autoload :Stub,             "vmstat/stub"
  autoload :Snapshot,         "vmstat/snapshot"
  autoload :Solaris,          "vmstat/solaris"
  extend Stub # the default empty implementation

  # @!method self.boot_time
  # Fetches the boot time of the system.
  # @return [Time] the boot time as regular time object.
  # @example
  #   Vmstat.boot_time # => 2012-10-09 18:42:37 +0200
  
  # @!method self.cpu
  # Fetches the cpu statistics (usage counter for user, nice, system and idle)
  # @return [Array<Vmstat::Cpu>] the array of cpu counter
  # @example
  #   Vmstat.cpu # => [#<struct Vmstat::Cpu ...>, #<struct Vmstat::Cpu ...>]
  
  # @!method self.disk(path)
  # Fetches the usage data and other useful disk information for the given path.
  # @param [String] path the path (mount point or device path) to the disk
  # @return [Vmstat::Disk] the disk information
  # @example
  #   Vmstat.disk("/") # => #<struct Vmstat::Disk type=:hfs, ...>
  
  # @!method self.load_average
  # Fetches the load average for the current system.
  # @return [Vmstat::LoadAverage] the load average data
  # @example
  #   Vmstat.load_average # => #<struct Vmstat::LoadAverage one_minute=...>
  
  # @!method self.memory
  # Fetches the memory usage information.
  # @return [Vmstat::Memory] the memory data like free, used und total.
  # @example
  #   Vmstat.memory # => #<struct Vmstat::Memory ...>
  
  # @!method self.network_interfaces
  # Fetches the information for all available network devices.
  # @return [Array<Vmstat::NetworkInterface>] the network device information
  # @example
  #   Vmstat.network_interfaces # => [#<struct Vmstat::NetworkInterface ...>, ...]
  
  # @!method self.pagesize
  # Fetches pagesize of the current system.
  # @return [Fixnum] the pagesize of the current system in bytes.
  # @example
  #   Vmstat.pagesize # => 4096
  
  # @!method self.task
  # Fetches time and memory usage for the current process.
  # @note Currently only on Mac OS X
  # @return [Array<Vmstat::Task>] the network device information
  # @example
  #   Vmstat.task # => #<struct Vmstat::Task ...>

  # Creates a full snapshot of the systems hardware statistics.
  # @param [Array<String>] paths the paths to the disks to snapshot.
  # @return [Vmstat::Snapshot] a snapshot of all statistics.
  # @example
  #   Vmstat.snapshot # => #<struct Vmstat::Snapshot ...>
  def self.snapshot(paths = ["/"])
    Snapshot.new(paths)
  end

  # Filters all available ethernet devices.
  # @return [Array<NetworkInterface>] the ethernet devices
  def self.ethernet_devices
    network_interfaces.select(&:ethernet?)
  end

  # Filters all available loopback devices.
  # @return [Array<NetworkInterface>] the loopback devices
  def self.loopback_devices
    network_interfaces.select(&:loopback?)
  end
end

require "vmstat/vmstat" # native lib

if RUBY_PLATFORM =~ /linux/
  Vmstat.send(:extend, Vmstat::ProcFS)
elsif RUBY_PLATFORM =~ /(net|open)bsd/
  # command based implementation of mem, net, cpu
  require "vmstat/netopenbsd"
elsif RUBY_PLATFORM =~ /solaris|smartos/
  # command based implementation of mem, net, cpu
  Vmstat.send(:include, Vmstat::Solaris)
end
