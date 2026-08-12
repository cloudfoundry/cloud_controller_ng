require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    class StoreError < StandardError; end

    class ConcurrentRedisStore
      def initialize(redis, counter_ttl_seconds: nil)
        @redis = redis
        @counter_ttl_seconds = counter_ttl_seconds
      end

      def self.new_socket(socket, connection_pool_size: nil, counter_ttl_seconds: nil)
        connection_pool_size ||= VCAP::CloudController::Config.config.get(:puma, :max_threads) || 1
        redis = ConnectionPool::Wrapper.new(size: connection_pool_size) do
          Redis.new(timeout: 1, path: socket)
        end
        new(redis, counter_ttl_seconds: counter_ttl_seconds)
      end

      def increment(key, logger)
        count = @redis.incr(key).to_i
        @redis.expire(key, @counter_ttl_seconds) if @counter_ttl_seconds
        count
      rescue Redis::BaseError => e
        logger.error("Redis error: #{e.class} - #{e.message}")
        raise StoreError.new("increment failed: #{e.message}")
      end

      def decrement(key, logger)
        count = @redis.decr(key).to_i
        @redis.incr(key) if count < 0
        [count, 0].max
      rescue Redis::BaseError => e
        logger.error("Redis error: #{e.class} - #{e.message}")
        raise StoreError.new("decrement failed: #{e.message}")
      end
    end

    class ConcurrentInMemoryStore
      def initialize
        @mutex = Mutex.new
        @data = {}
      end

      def increment(key, _logger)
        @mutex.synchronize do
          @data[key] = (@data[key] || 0) + 1
        end
      end

      def decrement(key, _logger)
        @mutex.synchronize do
          return 0 unless @data.key?(key)

          @data[key] -= 1
          @data.delete(key) if @data[key] <= 0
          @data[key] || 0
        end
      end
    end

    class ConcurrencyLimiter
      AVERAGE_RESPONSE_TIME_SEC = 0.1

      @instance_mutex = Mutex.new

      def self.instance(logger, blocking_limit: nil, logging_limit: nil, redis_connection_pool_size: nil, redis_counter_ttl_seconds: nil)
        return @instance if @instance

        @instance_mutex.synchronize do
          @instance ||= new(logger,
                            blocking_limit: blocking_limit,
                            logging_limit: logging_limit,
                            redis_connection_pool_size: redis_connection_pool_size,
                            redis_counter_ttl_seconds: redis_counter_ttl_seconds)
        end
        @instance
      end

      def initialize(logger, blocking_limit: nil, logging_limit: nil, redis_connection_pool_size: nil, redis_counter_ttl_seconds: nil)
        @blocking_limit = blocking_limit
        @logging_limit = logging_limit
        @redis_connection_pool_size = redis_connection_pool_size
        @redis_counter_ttl_seconds = redis_counter_ttl_seconds
        @logger = logger
      end

      def try_increment?(user_guid, rate_limit_headers)
        key = "#{key_prefix}:#{user_guid}"
        count = store.increment(key, @logger)

        @logger.info("Concurrency limit warning for user '#{user_guid}', count=#{count} exceeded logging_limit=#{@logging_limit}") if @logging_limit && count > @logging_limit

        if @blocking_limit
          rate_limit_headers.limit = @blocking_limit.to_s
          if count > @blocking_limit
            store.decrement(key, @logger)
            rate_limit_headers.remaining = '0'
            return false
          end
          rate_limit_headers.remaining = (@blocking_limit - count).to_s
        end

        true
      rescue StoreError
        # fail open
        true
      end

      def decrement(user_guid)
        key = "#{key_prefix}:#{user_guid}"
        store.decrement(key, @logger)
      rescue StoreError
        # fail open
      end

      def suggested_retry_after
        base = [(@blocking_limit.to_i * AVERAGE_RESPONSE_TIME_SEC).ceil, 1].max
        delay_range = [(base * 0.5).floor, 1].max..(base * 1.5).ceil
        rand(delay_range).to_i
      end

      def error_name
        'ConcurrentRequestLimitExceeded'
      end

      def error_name_ip_based
        'IPBasedConcurrentRequestLimitExceeded'
      end

      def header_suffix
        'Concurrent'
      end

      private

      def key_prefix
        'concurrent-rate-limit'
      end

      def store
        return @store if defined?(@store)

        redis_socket = VCAP::CloudController::Config.config.get(:redis, :socket)
        @store = if redis_socket.nil?
                   ConcurrentInMemoryStore.new
                 else
                   ConcurrentRedisStore.new_socket(redis_socket, connection_pool_size: @redis_connection_pool_size, counter_ttl_seconds: @redis_counter_ttl_seconds)
                 end
      end
    end

    class ConcurrencyRateLimiter
      include CloudFoundry::Middleware::ClientIp

      def initialize(app, opts)
        @app = app
        @logger = opts[:logger]
        @concurrency_limiter = ConcurrencyLimiter.instance(
          opts[:logger],
          blocking_limit: opts[:blocking_limit],
          logging_limit: opts[:logging_limit],
          redis_connection_pool_size: opts[:redis_connection_pool_size],
          redis_counter_ttl_seconds: opts[:redis_counter_ttl_seconds]
        )
        @header_suffix = @concurrency_limiter.header_suffix
      end

      def call(env)
        rate_limit_headers = RateLimitHeaders.new(@header_suffix)
        user_guid = nil
        incremented = false

        if apply_rate_limiting?(env)
          user_guid = get_user_id(env)
          incremented = @concurrency_limiter.try_increment?(user_guid, rate_limit_headers)
          return too_many_requests!(env, user_guid, rate_limit_headers) unless incremented
        end

        status, headers, body = @app.call(env)
        [status, headers.merge(rate_limit_headers.to_hash), body]
      ensure
        @concurrency_limiter.decrement(user_guid) if incremented
      end

      private

      def get_user_id(env)
        user_token?(env) ? env['cf.user_guid'] : client_ip(ActionDispatch::Request.new(env))
      end

      def user_token?(env)
        !!env['cf.user_guid']
      end

      def too_many_requests!(env, user_guid, rate_limit_headers)
        @logger.info("Concurrent rate limit exceeded for user '#{user_guid}' " \
                     "path=#{env['PATH_INFO']} limit=#{rate_limit_headers.limit} remaining=#{rate_limit_headers.remaining}")
        headers = rate_limit_headers.to_hash
        headers['Retry-After'] = @concurrency_limiter.suggested_retry_after.to_s
        headers['Content-Type'] = 'text/plain; charset=utf-8'
        message = rate_limit_error(env).to_json
        headers['Content-Length'] = message.length.to_s
        [429, headers, [message]]
      end

      def apply_rate_limiting?(env)
        request = ActionDispatch::Request.new(env)
        !basic_auth?(env) && !internal_api?(request) && !root_api?(request)
      end

      def root_api?(request)
        request.fullpath.match(%r{\A(?:/v2/info|/v3|/|/healthz)\z})
      end

      def internal_api?(request)
        request.fullpath.match(%r{\A/internal})
      end

      def basic_auth?(env)
        auth = Rack::Auth::Basic::Request.new(env)
        auth.provided? && auth.basic?
      end

      def rate_limit_error(env)
        error_name = user_token?(env) ? @concurrency_limiter.error_name : @concurrency_limiter.error_name_ip_based
        api_error = CloudController::Errors::ApiError.new_from_details(error_name)
        version   = env['PATH_INFO'][0..2]
        if version == '/v2'
          ErrorPresenter.new(api_error, Rails.env.test?, V2ErrorHasher.new(api_error)).to_hash
        elsif version == '/v3'
          ErrorPresenter.new(api_error, Rails.env.test?, V3ErrorHasher.new(api_error)).to_hash
        end
      end
    end
  end
end
