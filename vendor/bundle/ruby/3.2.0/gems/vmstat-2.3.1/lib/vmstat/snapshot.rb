module Vmstat
  # Snapshots help to gather information about the whole system quickly.
  # @attr [Time] at the timestamp, when the snapshot was created.
  # @attr [Time] boot_time the timestamp, when the system booted.
  # @attr [Array<Vmstat::Cpu>] cpus the data of each and every cpu.
  # @attr [Array<Vmstat::Disk>] disks the disks that are part of the snapshot.
  # @attr [Vmstat::LoadAverage] load_average current load average at the time
  #   when the snapshot toke place.
  # @attr [Vmstat::Memory] memory the memory data snapshot.
  # @attr [Array<Vmstat::NetworkInterface>] network_interfaces the network
  #   interface data snapshots per network interface.
  # @attr [Vmstat::Task] task optionally the information for the current task
  # @example Creating a snapshot
  #   snapshop = Vmstat::Snapshop.new(["/dev/disk0", "/dev/disk1"])
  class Snapshot
    attr_reader :at, :boot_time, :cpus, :disks, :load_average,
                :memory, :network_interfaces, :task

    # Create a new snapshot for system informations. The passed paths array,
    # should contain the disk paths to create a snapshot for.
    # @param [Array<String>] paths the paths to create snapshots for
    def initialize(paths = [])
      @at = Time.now
      @boot_time = Vmstat.boot_time
      @cpus = Vmstat.cpu
      @disks = paths.map { |path| Vmstat.disk(path) }
      @load_average = Vmstat.load_average
      @memory = Vmstat.memory
      @network_interfaces = Vmstat.network_interfaces
      @task = Vmstat.task if Vmstat.respond_to? :task
    end
  end
end
