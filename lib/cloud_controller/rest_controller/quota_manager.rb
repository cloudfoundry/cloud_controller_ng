# Copyright (c) 2009-2012 VMware, Inc.

require "restclient"

module VCAP::CloudController::RestController
  module QuotaManager
    class BlindApprovalToken
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

    class BlindApproval
      def self.fetch_quota_token(quota_request)
        BlindApprovalToken.new
      end
    end

    class MoneyMakerApproval
      class << self
        def fetch_quota_token(quota_request)
          url     = quota_manager_url(quota_request[:path])
          body    = Yajl::Encoder.encode(quota_request[:body])
          headers = {
            :content_type  => :json,
            :accept        => :json,
            :authorization => "testtoken"
          }

          response = RestClient.post(url, body, headers)
        rescue Exception => e
          BlindApprovalToken.new
        end

        def quota_manager_url(path)
          "http://localhost:31004#{path}"
        end
      end
    end

    class << self
      def policy
        # @policy ||= BlindApproval
        @policy ||= MoneyMakerApproval
      end

      def policy=(policy)
        @policy = policy
      end

      def fetch_quota_token(quota_request)
        p = quota_request ? policy : BlindApproval
        p.fetch_quota_token(quota_request)
      end
    end
  end
end
