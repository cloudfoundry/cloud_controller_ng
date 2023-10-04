require 'base_rate_limiter'

module CloudFoundry
  module Middleware
    class RateLimiterV2API < BaseRateLimiter
      EXPIRING_REQUEST_COUNTER = ExpiringRequestCounter.new('v2-rate-limit')

      def initialize(app, opts)
        @per_process_general_limit = opts[:per_process_general_limit]
        @global_general_limit      = opts[:global_general_limit]
        @per_process_admin_limit   = opts[:per_process_admin_limit]
        @global_admin_limit        = opts[:global_admin_limit]
        super(app, opts[:logger], EXPIRING_REQUEST_COUNTER, opts[:interval], 'V2-API')
      end

      private

      def apply_rate_limiting?(env)
        !basic_auth?(env) && v2_api?(env) && !v2_rate_limit_exempted?
      end

      def v2_api?(env)
        request = ActionDispatch::Request.new(env)
        request.fullpath.match(%r{\A/v2/(?!(info)).+})
      end

      def global_request_limit(_env)
        admin? ? @global_admin_limit : @global_general_limit
      end

      def per_process_request_limit(_env)
        admin? ? @per_process_admin_limit : @per_process_general_limit
      end

      def v2_rate_limit_exempted?
        VCAP::CloudController::SecurityContext.v2_rate_limit_exempted?
      end

      def rate_limit_error(_env)
        api_error = CloudController::Errors::ApiError.new_from_details('RateLimitV2APIExceeded')
        ErrorPresenter.new(api_error, Rails.env.test?, V2ErrorHasher.new(api_error)).to_hash
      end
    end
  end
end
