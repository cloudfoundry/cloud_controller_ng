module VCAP::CloudController
  class StagingDiskCalculator
    class LimitExceeded < StandardError; end

    def get_limit(requested_limit)
      requested_limit = requested_limit.to_i
      return minimum_limit if requested_limit < minimum_limit
      raise LimitExceeded if requested_limit > maximum_limit
      requested_limit
    end

    def minimum_limit
      Config.config.get(:staging, :minimum_staging_disk_mb) || 4096
    end

    def maximum_limit
      configured_running_maximum = Config.config.get(:maximum_app_disk_in_mb)
      return minimum_limit if configured_running_maximum.nil? || configured_running_maximum < minimum_limit
      configured_running_maximum
    end
  end
end
