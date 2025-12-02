## Generated from metric.proto for events
require "beefcake"

module Sonde

  class ValueMetric
    include Beefcake::Message
  end

  class CounterEvent
    include Beefcake::Message
  end

  class ContainerMetric
    include Beefcake::Message
  end

  class ValueMetric
    required :name, :string, 1
    required :value, :double, 2
    required :unit, :string, 3
  end

  class CounterEvent
    required :name, :string, 1
    required :delta, :uint64, 2
    optional :total, :uint64, 3
  end

  class ContainerMetric
    required :applicationId, :string, 1
    required :instanceIndex, :int32, 2
    required :cpuPercentage, :double, 3
    required :memoryBytes, :uint64, 4
    required :diskBytes, :uint64, 5
    optional :memoryBytesQuota, :uint64, 6
    optional :diskBytesQuota, :uint64, 7
  end
end
