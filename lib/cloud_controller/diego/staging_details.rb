module VCAP::CloudController
  module Diego
    class StagingDetails
      attr_accessor :droplet, :staging_memory_in_mb, :staging_disk_in_mb, :package,
        :environment_variables, :lifecycle, :start_after_staging
    end
  end
end
