require 'mixins/user_id'
require 'mixins/internal_or_root_api'
require 'mixins/too_many_requests'
require 'mixins/basic_auth'
require 'concurrent_request_counter'

module CloudFoundry
  module Middleware
    class ConcurrencyRateLimiter
      include CloudFoundry::Middleware::UserId
      include CloudFoundry::Middleware::InternalOrRootApi
      include CloudFoundry::Middleware::TooManyRequests
      include CloudFoundry::Middleware::BasicAuth

      def initialize(app, opts)
        @app = app
        @logger = opts[:logger]
        @counter = ConcurrentRequestCounter.instance(
          'concurrent-rate-limit',
          blocking_limit: opts[:blocking_limit],
          logging_limit: opts[:logging_limit],
          redis_connection_pool_size: opts[:redis_connection_pool_size],
          redis_counter_ttl_seconds: opts[:redis_counter_ttl_seconds]
        )
      end

      def call(env)
        user_guid = nil
        decrement_after_call = false

        if apply_rate_limiting?(env)
          user_guid = get_user_id(env)
          decrement_after_call = @counter.try_increment?(user_guid, @logger)
          return too_many_requests!(env, rate_limit_error_name(env), retry_after: suggested_retry_after) unless decrement_after_call
        end

        @app.call(env)
      ensure
        @counter.decrement(user_guid, @logger) if decrement_after_call
      end

      private

      def suggested_retry_after
        rand(1..5).to_i
      end

      def apply_rate_limiting?(env)
        request = ActionDispatch::Request.new(env)
        !basic_auth?(env) && !internal_api?(request) && !root_api?(request)
      end

      def rate_limit_error_name(env)
        user_token?(env) ? 'ConcurrentRequestLimitExceeded' : 'IPBasedConcurrentRequestLimitExceeded'
      end
    end
  end
end
