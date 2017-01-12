module VCAP::CloudController
  class StagingMemoryCalculator
    class SpaceQuotaExceeded < StandardError; end
    class OrgQuotaExceeded < StandardError; end

    def get_limit(requested_limit, space, org)
      staging_memory = [minimum_limit, requested_limit].compact.max
      space_quota_exceeded!(staging_memory) unless space.has_remaining_memory(staging_memory)
      org_quota_exceeded!(staging_memory) unless org.has_remaining_memory(staging_memory)
      staging_memory
    end

    def minimum_limit
      Config.config[:staging][:minimum_staging_memory_mb] || 1024
    end

    private

    def org_quota_exceeded!(staging_memory)
      raise OrgQuotaExceeded.new("staging requires #{staging_memory}M memory")
    end

    def space_quota_exceeded!(staging_memory)
      raise SpaceQuotaExceeded.new("staging requires #{staging_memory}M memory")
    end
  end
end
