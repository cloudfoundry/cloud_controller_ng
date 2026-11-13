require 'base_concurrency_rate_limiter'
require 'mixins/basic_auth'
require 'mixins/internal_or_root_api'
require 'concurrent_request_counter'

module CloudFoundry
  module Middleware
    class ConcurrencyRateLimiter < BaseConcurrencyRateLimiter
      include CloudFoundry::Middleware::BasicAuth
      include CloudFoundry::Middleware::InternalOrRootApi

      def initialize(app, opts)
        counter = ConcurrentRequestCounter.instance(
          'concurrent-rate-limit',
          blocking_limit: opts[:blocking_limit],
          logging_limit: opts[:logging_limit]
        )
        super(app, opts[:logger], counter)
      end

      private

      def apply_rate_limiting?(env)
        request = ActionDispatch::Request.new(env)
        !basic_auth?(env) && !internal_api?(request) && !root_api?(request)
      end

      def rate_limit_error_name(env)
        user_token?(env) ? 'ConcurrentRequestLimitExceeded' : 'IPBasedConcurrentRequestLimitExceeded'
      end

      def suggested_retry_after
        rand(1..5).to_i
      end
    end
  end
end
