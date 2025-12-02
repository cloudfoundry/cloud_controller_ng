module Fog
  module Google
    class Compute
      class MachineType < Fog::Model
        identity :name

        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :deprecated
        attribute :description
        attribute :guest_cpus, :aliases => "guestCpus"
        attribute :id
        attribute :is_shared_cpu, :aliases => "isSharedCpu"
        attribute :kind
        attribute :maximum_persistent_disks, :aliases => "maximumPersistentDisks"
        attribute :maximum_persistent_disks_size_gb, :aliases => "maximumPersistentDisksSizeGb"
        attribute :memory_mb, :aliases => "memoryMb"
        attribute :scratch_disks, :aliases => "scratchDisks"
        attribute :self_link, :aliases => "selfLink"
        attribute :zone
      end
    end
  end
end
