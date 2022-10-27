module Logcache
  class ContainerMetricBatch
    attr_accessor :cpu_percentage, :memory_bytes, :disk_bytes, :log_rate,
      :disk_bytes_quota, :memory_bytes_quota, :log_rate_limit,
      :instance_index
  end
end
