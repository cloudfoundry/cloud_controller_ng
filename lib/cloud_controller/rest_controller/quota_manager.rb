# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  module QuotaManager
    class BlindApproval
      class ApprovedToken
        def approved?
          true
        end

        def declined?
          false
        end

        def reason
        end

        def abandon(reason)
        end

        def commit
        end
      end

      def self.fetch_quota_token(request_body)
        ApprovedToken.new
      end
    end

    class MoneyMakerApproval
      # TODO
    end

    class << self
      def policy
        @policy ||= BlindApproval
      end

      def policy=(policy)
        @policy = policy
      end

      def fetch_quota_token(request_body)
        policy.fetch_quota_token(request_body)
      end
    end
  end
end
