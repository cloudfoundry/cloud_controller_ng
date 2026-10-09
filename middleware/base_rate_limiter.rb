require 'mixins/user_id'
require 'mixins/too_many_requests'
require 'mixins/basic_auth'
require 'mixins/user_reset_interval'
require 'redis'

module CloudFoundry
  module Middleware
    class ExpiringRequestCounter
      include CloudFoundry::Middleware::UserResetInterval

      def initialize(key_prefix, redis_connection_pool_size: nil)
        @key_prefix = key_prefix
        @redis_connection_pool_size = redis_connection_pool_size
      end

      def increment(user_guid, reset_interval_in_minutes, logger)
        key = "#{@key_prefix}:#{user_guid}"
        expires_in = next_expires_in(user_guid, reset_interval_in_minutes)
        store.increment(key, expires_in, logger)
      end

      private

      def store
        return @store if defined?(@store)

        redis_socket = VCAP::CloudController::Config.config.get(:redis, :socket)
        @store = redis_socket.nil? ? InMemoryStore.new : RedisStore.new(redis_socket, @redis_connection_pool_size)
      end

      class InMemoryStore
        Counter = Struct.new(:value, :expires_at)

        def initialize
          @mutex = Mutex.new
          @data = {}
        end

        def increment(key, expires_in, _)
          @mutex.synchronize do
            if !@data.key?(key) || (ttl = @data[key].expires_at - Time.now.to_i) <= 0 # not existing or expired
              @data[key] = Counter.new(1, Time.now.to_i + expires_in)
              [1, expires_in]
            else
              [@data[key].value += 1, ttl]
            end
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

        def increment(key, expires_in, logger)
          _, count_str, ttl_int = @redis.multi do |transaction|
            transaction.set(key, 0, ex: expires_in, nx: true) # nx => set only if not exists
            transaction.incr(key)
            transaction.ttl(key)
          end

          [count_str.to_i, ttl_int]
        rescue Redis::BaseError => e
          logger.error("Redis error: #{e.class} - #{e.message}")
          [1, expires_in]
        end
      end
    end

    class RateLimitHeaders
      attr_accessor :limit, :reset, :remaining

      def initialize(suffix)
        @prefix = 'X-RateLimit'
        @suffix = suffix.nil? ? nil : '-' + suffix
        @limit = nil
        @reset = nil
        @remaining = nil
      end

      def to_hash
        return {} if [@limit, @reset, @remaining].all?(&:nil?)

        { "#{@prefix}-Limit#{@suffix}" => @limit, "#{@prefix}-Reset#{@suffix}" => @reset, "#{@prefix}-Remaining#{@suffix}" => @remaining }
      end
    end

    class BaseRateLimiter
      include CloudFoundry::Middleware::UserId
      include CloudFoundry::Middleware::TooManyRequests
      include CloudFoundry::Middleware::BasicAuth

      def initialize(app, logger, expiring_request_counter, reset_interval, header_suffix=nil)
        @app = app
        @logger = logger
        @expiring_request_counter = expiring_request_counter
        @reset_interval = reset_interval
        @header_suffix = header_suffix
      end

      def call(env)
        rate_limit_headers = RateLimitHeaders.new(@header_suffix)

        if apply_rate_limiting?(env)
          user_guid = get_user_id(env)

          count, expires_in = @expiring_request_counter.increment(user_guid, @reset_interval, @logger)

          rate_limit_headers.limit = global_request_limit(env).to_s
          rate_limit_headers.reset = (Time.now.to_i + expires_in).to_s
          rate_limit_headers.remaining = estimate_remaining(env, count)

          return too_many_requests!(env, rate_limit_error_name(env), retry_after: expires_in, extra_headers: rate_limit_headers.to_hash) if exceeded_rate_limit(count, env)
        end

        status, headers, body = @app.call(env)
        [status, headers.merge(rate_limit_headers.to_hash), body]
      end

      private

      def apply_rate_limiting?(_env)
        raise 'method should be implemented in concrete class'
      end

      def global_request_limit(_env)
        raise 'method should be implemented in concrete class'
      end

      def rate_limit_error_name(_env)
        raise 'method should be implemented in concrete class'
      end

      def per_process_request_limit(_env)
        raise 'method should be implemented in concrete class'
      end

      def exceeded_rate_limit(count, env)
        count > per_process_request_limit(env)
      end

      def estimate_remaining(env, new_count)
        global_limit = global_request_limit(env)
        limit = per_process_request_limit(env)
        return '0' unless limit > 0

        estimate = ((limit - new_count).to_f / limit).floor(1) * global_limit
        [0, estimate].max.to_i.to_s
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end
    end
  end
end
