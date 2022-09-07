module VCAP::CloudController
  class QuotaValidatingStagingLogRateLimitCalculator
    class SpaceQuotaExceeded < StandardError; end
    class OrgQuotaExceeded < StandardError; end

    def get_limit(requested_limit, space, org)
      if requested_limit.nil?
        requested_limit = -1
      end

      requested_limit = requested_limit.to_i

      space_quota_exceeded!(requested_limit) unless space.has_remaining_log_rate_limit(requested_limit)
      org_quota_exceeded!(requested_limit) unless org.has_remaining_log_rate_limit(requested_limit)
      requested_limit
    end

    private

    def org_quota_exceeded!(staging_log_rate_limit)
      raise OrgQuotaExceeded.new("staging requires #{staging_log_rate_limit} bytes per second")
    end

    def space_quota_exceeded!(staging_log_rate_limit)
      raise SpaceQuotaExceeded.new("staging requires #{staging_log_rate_limit} bytes per second")
    end
  end
end
