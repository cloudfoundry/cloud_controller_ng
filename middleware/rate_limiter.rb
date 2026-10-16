require 'base_rate_limiter'
require 'mixins/internal_or_root_api'

module CloudFoundry
  module Middleware
    class RateLimiter < BaseRateLimiter
      include CloudFoundry::Middleware::InternalOrRootApi

      EXPIRING_REQUEST_COUNTER = ExpiringRequestCounter.new('rate-limit')

      def initialize(app, opts)
        @per_process_general_limit         = opts[:per_process_general_limit]
        @global_general_limit              = opts[:global_general_limit]
        @per_process_unauthenticated_limit = opts[:per_process_unauthenticated_limit]
        @global_unauthenticated_limit      = opts[:global_unauthenticated_limit]
        @per_process_admin_limit           = opts[:per_process_admin_limit] || -1
        @global_admin_limit                = opts[:global_admin_limit] || -1
        super(app, opts[:logger], EXPIRING_REQUEST_COUNTER, opts[:interval])
      end

      private

      def apply_rate_limiting?(env)
        request = ActionDispatch::Request.new(env)
        return false if basic_auth?(env)
        return false if internal_api?(request) || root_api?(request)
        return false if per_process_request_limit(env) < 0

        true
      end

      def global_request_limit(env)
        return @global_admin_limit if admin?

        user_token?(env) ? @global_general_limit : @global_unauthenticated_limit
      end

      def per_process_request_limit(env)
        return @per_process_admin_limit if admin?

        user_token?(env) ? @per_process_general_limit : @per_process_unauthenticated_limit
      end

      def rate_limit_error_name(env)
        user_token?(env) ? 'RateLimitExceeded' : 'IPBasedRateLimitExceeded'
      end
    end
  end
end
