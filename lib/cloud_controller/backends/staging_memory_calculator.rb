module VCAP::CloudController
  class StagingMemoryCalculator
    class SpaceQuotaExceeded < StandardError; end
    class OrgQuotaExceeded < StandardError; end

    def get_limit(requested_limit, space, org)
      return minimum_limit if requested_limit.nil? || requested_limit < minimum_limit
      raise SpaceQuotaExceeded if !space.has_remaining_memory(requested_limit)
      raise OrgQuotaExceeded if !org.has_remaining_memory(requested_limit)
      requested_limit
    end

    def minimum_limit
      Config.config[:minimum_staging_memory_mb] || 1024
    end
  end
end
