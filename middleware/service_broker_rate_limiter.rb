require 'concurrent-ruby'

module CloudFoundry
  module Middleware
    class ConcurrentRequestCounter
      def initialize(key_prefix)
        @key_prefix = key_prefix
        @mutex = Mutex.new
        @data = {}
      end

      def try_increment?(user_guid, max_concurrent_requests, logger)
        key = "#{@key_prefix}:#{user_guid}"
        @mutex.synchronize do
          @data[key] = Concurrent::Semaphore.new(max_concurrent_requests) unless @data.key?(key)
          @data[key].try_acquire
        end
      end

      def decrement(user_guid, logger)
        key = "#{@key_prefix}:#{user_guid}"
        @mutex.synchronize do
          @data[key].release if @data.key?(key)
        end
      end
    end

    class ServiceBrokerRateLimiter
      CONCURRENT_REQUEST_COUNTER = ConcurrentRequestCounter.new('service-broker-rate-limit')

      def initialize(app, opts)
        @app = app
        @logger = opts[:logger]
        @max_concurrent_requests = opts[:max_concurrent_requests]
        @broker_timeout_seconds = opts[:broker_timeout_seconds]
        @concurrent_request_counter = CONCURRENT_REQUEST_COUNTER
      end

      def call(env)
        decrement_after_call = false
        user_guid = env['cf.user_guid']
        if apply_rate_limiting?(env)
          if @concurrent_request_counter.try_increment?(user_guid, @max_concurrent_requests, @logger)
            decrement_after_call = true
          else
            return too_many_requests!(env, user_guid)
          end
        end

        @app.call(env)
      ensure
        @concurrent_request_counter.decrement(user_guid, @logger) if decrement_after_call
      end

      private

      def apply_rate_limiting?(env)
        request = ActionDispatch::Request.new(env)
        !admin? && is_service_request?(request) && rate_limit_method?(request)
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end

      def is_service_request?(request)
        [
          %r{\A/v2/service_instances},
          %r{\A/v2/service_bindings},
          %r{\A/v2/service_keys},
          %r{\A/v3/service_instances},
          %r{\A/v3/service_credential_bindings},
          %r{\A/v3/service_route_bindings},
        ].any? { |re| request.fullpath.match(re) }
      end

      def rate_limit_method?(request)
        %w(PATCH PUT POST DELETE).include?(request.method)
      end

      def suggested_retry_after
        delay_range = (@broker_timeout_seconds * 0.5).floor..(@broker_timeout_seconds * 1.5).ceil
        rand(delay_range).to_i
      end

      def rate_limit_error(env)
        api_error = CloudController::Errors::ApiError.new_from_details('ServiceBrokerRateLimitExceeded')
        version   = env['PATH_INFO'][0..2]
        if version == '/v2'
          ErrorPresenter.new(api_error, Rails.env.test?, V2ErrorHasher.new(api_error)).to_hash
        elsif version == '/v3'
          ErrorPresenter.new(api_error, Rails.env.test?, V3ErrorHasher.new(api_error)).to_hash
        end
      end

      def too_many_requests!(env, user_guid)
        @logger.info("Service broker concurrent rate limit exceeded for user '#{user_guid}'")
        headers = {}
        headers['Retry-After'] = suggested_retry_after.to_s
        headers['Content-Type'] = 'text/plain; charset=utf-8'
        message = rate_limit_error(env).to_json
        headers['Content-Length'] = message.length.to_s
        [429, headers, [message]]
      end
    end
  end
end
