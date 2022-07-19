module VCAP::CloudController
  module Diego
    class StagingDetails
      attr_accessor :staging_guid, :staging_memory_in_mb, :staging_disk_in_mb, :staging_log_rate_limit_bytes_per_second, :package,
        :environment_variables, :lifecycle, :start_after_staging, :isolation_segment
    end
  end
end
