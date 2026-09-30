require 'mixins/too_many_requests'
require 'concurrent_request_counter'

module CloudFoundry
  module Middleware
    RateLimitEndpoint = Struct.new(:endpoint_pattern, :request_methods)

    RATE_LIMITED_ENDPOINTS = [
      RateLimitEndpoint.new(%r{\A/v2/(service_instances|service_bindings|service_keys)}, %w[PUT POST DELETE]),
      RateLimitEndpoint.new(%r{\A/v3/(service_instances|service_credential_bindings|service_route_bindings)/.+/parameters\z}, %w[GET])
    ].freeze

    class ServiceBrokerRateLimiter
      include CloudFoundry::Middleware::TooManyRequests

      def initialize(app, opts)
        @app = app
        @logger = opts[:logger]
        @broker_timeout_seconds = opts[:broker_timeout_seconds]
        @counter = ConcurrentRequestCounter.instance(
          'service-broker-rate-limit',
          blocking_limit: opts[:max_concurrent_requests],
          redis_connection_pool_size: opts[:redis_connection_pool_size],
          redis_counter_ttl_seconds: opts[:redis_counter_ttl_seconds]
        )
      end

      def call(env)
        decrement_after_call = false
        user_guid = env['cf.user_guid']

        if apply_rate_limiting?(env)
          decrement_after_call = @counter.try_increment?(user_guid, @logger)
          unless decrement_after_call
            @logger.info("Service broker concurrent rate limit exceeded for user '#{user_guid}'")
            return too_many_requests!(env, 'ServiceBrokerRateLimitExceeded', retry_after: suggested_retry_after)
          end
        end

        @app.call(env)
      ensure
        @counter.decrement(user_guid, @logger) if decrement_after_call
      end

      private

      def apply_rate_limiting?(env)
        request = ActionDispatch::Request.new(env)
        !admin? && is_rate_limited_service_request?(request)
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end

      def is_rate_limited_service_request?(request)
        RATE_LIMITED_ENDPOINTS.any? do |endpoint|
          endpoint.endpoint_pattern.match?(request.fullpath) && endpoint.request_methods.include?(request.method)
        end
      end

      def suggested_retry_after
        delay_range = (@broker_timeout_seconds * 0.5).floor..(@broker_timeout_seconds * 1.5).ceil
        rand(delay_range).to_i
      end
    end
  end
end
