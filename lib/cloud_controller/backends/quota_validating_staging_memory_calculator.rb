require 'cloud_controller/backends/non_quota_validating_staging_memory_calculator'

module VCAP::CloudController
  class QuotaValidatingStagingMemoryCalculator < NonQuotaValidatingStagingMemoryCalculator
    class SpaceQuotaExceeded < StandardError; end
    class OrgQuotaExceeded < StandardError; end

    def get_limit(requested_limit, space, org)
      requested_limit = requested_limit.to_i
      return minimum_limit if requested_limit < minimum_limit
      space_quota_exceeded!(requested_limit) unless space.has_remaining_memory(requested_limit)
      org_quota_exceeded!(requested_limit) unless org.has_remaining_memory(requested_limit)
      requested_limit
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
