require 'concurrent-ruby'
require 'redis'

module CloudFoundry
  module Middleware
    RateLimitEndpoint = Struct.new(:endpoint_pattern, :request_methods)

    RATE_LIMITED_ENDPOINTS = [
      RateLimitEndpoint.new(%r{\A/v2/(service_instances|service_credential_bindings|service_route_bindings)}, %w[PUT POST DELETE PATCH]),
      RateLimitEndpoint.new(%r{\A/v3/(service_instances|service_credential_bindings|service_route_bindings)/.+/parameters\z}, %w[GET]),
      RateLimitEndpoint.new(%r{\A/v3/(service_instances|service_credential_bindings|service_route_bindings)}, %w[PUT])
    ].freeze

    class ConcurrentRequestCounter
      def initialize(key_prefix, redis_connection_pool_size: nil)
        @key_prefix = key_prefix
        @redis_connection_pool_size = redis_connection_pool_size
      end

      def try_increment?(user_guid, max_concurrent_requests, logger)
        key = "#{@key_prefix}:#{user_guid}"
        store.try_increment?(key, max_concurrent_requests, logger)
      end

      def decrement(user_guid, logger)
        key = "#{@key_prefix}:#{user_guid}"
        store.decrement(key, logger)
      end

      private

      def store
        return @store if defined?(@store)

        redis_socket = VCAP::CloudController::Config.config.get(:redis, :socket)
        @store = redis_socket.nil? ? InMemoryStore.new : RedisStore.new(redis_socket, @redis_connection_pool_size)
      end

      class InMemoryStore
        def initialize
          @mutex = Mutex.new
          @data = {}
        end

        def try_increment?(key, max_concurrent_requests, _)
          @mutex.synchronize do
            @data[key] = Concurrent::Semaphore.new(max_concurrent_requests) unless @data.key?(key)
            @data[key].try_acquire
          end
        end

        def decrement(key, _)
          @mutex.synchronize do
            @data[key].release if @data.key?(key)
          end
        end
      end

      class RedisStore
        def initialize(socket, connection_pool_size)
          connection_pool_size ||= VCAP::CloudController::Config.config.get(:puma, :max_threads) || 1
          @redis = ConnectionPool::Wrapper.new(size: connection_pool_size) do
            Redis.new(timeout: 1, path: socket)
          end
        end

        def try_increment?(key, max_concurrent_requests, logger)
          count_str = @redis.incr(key)
          return true if count_str.to_i <= max_concurrent_requests

          @redis.decr(key)
          false
        rescue Redis::BaseError => e
          logger.error("Redis error: #{e.inspect}")
          true
        end

        def decrement(key, logger)
          count_str = @redis.decr(key)
          @redis.incr(key) if count_str.to_i < 0
        rescue Redis::BaseError => e
          logger.error("Redis error: #{e.inspect}")
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
          return too_many_requests!(env, user_guid) unless @concurrent_request_counter.try_increment?(user_guid, @max_concurrent_requests, @logger)

          decrement_after_call = true

        end

        @app.call(env)
      ensure
        @concurrent_request_counter.decrement(user_guid, @logger) if decrement_after_call
      end

      private

      def apply_rate_limiting?(env)
        request = ActionDispatch::Request.new(env)
        !admin? && rate_limit_method?(request)
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end

      def rate_limit_method?(request)
        RATE_LIMITED_ENDPOINTS.any? do |endpoint|
          endpoint.endpoint_pattern.match?(request.fullpath) && endpoint.request_methods.include?(request.method)
        end
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
