require 'base_concurrency_rate_limiter'
require 'mixins/admin'
require 'concurrent_request_counter'

module CloudFoundry
  module Middleware
    RateLimitEndpoint = Struct.new(:endpoint_pattern, :request_methods)

    RATE_LIMITED_ENDPOINTS = [
      RateLimitEndpoint.new(%r{\A/v2/(service_instances|service_bindings|service_keys)}, %w[PUT POST DELETE]),
      RateLimitEndpoint.new(%r{\A/v3/(service_instances|service_credential_bindings|service_route_bindings)/.+/parameters\z}, %w[GET])
    ].freeze

    class ServiceBrokerRateLimiter < BaseConcurrencyRateLimiter
      include CloudFoundry::Middleware::Admin

      def initialize(app, opts)
        @broker_timeout_seconds = opts[:broker_timeout_seconds]
        counter = ConcurrentRequestCounter.instance(
          'service-broker-rate-limit',
          blocking_limit: opts[:max_concurrent_requests]
        )
        super(app, opts[:logger], counter)
      end

      private

      def apply_rate_limiting?(env)
        request = ActionDispatch::Request.new(env)
        !admin? && is_rate_limited_service_request?(request)
      end

      def rate_limit_error_name(_env)
        'ServiceBrokerRateLimitExceeded'
      end

      def suggested_retry_after
        delay_range = (@broker_timeout_seconds * 0.5).floor..(@broker_timeout_seconds * 1.5).ceil
        rand(delay_range).to_i
      end

      def is_rate_limited_service_request?(request)
        RATE_LIMITED_ENDPOINTS.any? do |endpoint|
          endpoint.endpoint_pattern.match?(request.fullpath) && endpoint.request_methods.include?(request.method)
        end
      end
    end
  end
end
