require 'mixins/user_id'
require 'mixins/too_many_requests'

module CloudFoundry
  module Middleware
    class BaseConcurrencyRateLimiter
      include CloudFoundry::Middleware::UserId
      include CloudFoundry::Middleware::TooManyRequests

      def initialize(app, logger, concurrent_request_counter)
        @app = app
        @logger = logger
        @counter = concurrent_request_counter
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

      def apply_rate_limiting?(_env)
        raise 'method should be implemented in concrete class'
      end

      def rate_limit_error_name(_env)
        raise 'method should be implemented in concrete class'
      end

      def suggested_retry_after
        raise 'method should be implemented in concrete class'
      end
    end
  end
end
