module VCAP::CloudController
  class NonQuotaValidatingStagingMemoryCalculator
    def get_limit(requested_limit, _space, _org)
      [minimum_limit, requested_limit].compact.max
    end

    def minimum_limit
      Config.config.get(:staging, :minimum_staging_memory_mb) || 1024
    end
  end
end
