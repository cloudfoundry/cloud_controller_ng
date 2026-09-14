require 'mixins/client_ip'
require 'digest'

module CloudFoundry
  module Middleware
    class StoreError < StandardError; end

    class ConcurrentRedisStore
      # Atomically checks the limit and increments only when there is room, so requests
      # that will be rejected never touch the counter. The whole check-and-increment runs
      # on the Redis server in a single round-trip, which removes both:
      #   - the "phantom" over-count under load (rejected requests transiently inflating the
      #     counter via increment-then-rollback, causing false rejections), and
      #   - the check-then-increment race between two concurrent requests.
      #
      # KEYS[1] = counter key
      # ARGV[1] = limit (>= 0): 0 rejects everything; a positive N caps at N.
      #           The limiter is deactivated in Ruby for negative limits, so they never reach here.
      # ARGV[2] = ttl in seconds (<= 0 means do not set an expiry)
      # Returns the post-increment count when admitted, or -1 when rejected (not incremented).
      ACQUIRE_SCRIPT = <<~LUA.freeze
        local limit = tonumber(ARGV[1])
        local ttl = tonumber(ARGV[2])
        local current = tonumber(redis.call('get', KEYS[1]) or '0')
        if current >= limit then
          return -1
        end
        local count = redis.call('incr', KEYS[1])
        if ttl > 0 then
          redis.call('expire', KEYS[1], ttl)
        end
        return count
      LUA
      ACQUIRE_SHA = Digest::SHA1.hexdigest(ACQUIRE_SCRIPT).freeze

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

      # Returns the post-increment count when admitted, or nil when the limit is reached.
      # The limit is always >= 0 (the limiter is deactivated in Ruby for negative limits).
      def try_acquire(key, limit, logger)
        count = eval_acquire(key, limit).to_i
        count.negative? ? nil : count
      rescue Redis::BaseError => e
        logger.error("Redis error: #{e.class} - #{e.message}")
        raise StoreError.new("acquire failed: #{e.message}")
      end

      def decrement(key, logger)
        count = @redis.decr(key).to_i
        @redis.incr(key) if count < 0
        [count, 0].max
      rescue Redis::BaseError => e
        logger.error("Redis error: #{e.class} - #{e.message}")
        raise StoreError.new("decrement failed: #{e.message}")
      end

      private

      # Runs ACQUIRE_SCRIPT by its cached SHA to avoid shipping the script body on every
      # request. Redis keeps the compiled script cached; if it isn't loaded yet (fresh server,
      # SCRIPT FLUSH), Redis replies NOSCRIPT and we fall back to EVAL once, which also caches it.
      def eval_acquire(key, limit)
        argv = [limit, @counter_ttl_seconds || 0]
        @redis.evalsha(ACQUIRE_SHA, keys: [key], argv: argv)
      rescue Redis::CommandError => e
        raise unless e.message.include?('NOSCRIPT')

        @redis.eval(ACQUIRE_SCRIPT, keys: [key], argv: argv)
      end
    end

    class ConcurrentInMemoryStore
      def initialize
        @mutex = Mutex.new
        @data = {}
      end

      # Atomic check-and-increment under the mutex: a rejected request never increments,
      # mirroring the Redis Lua behaviour so both stores are phantom-free. Returns the
      # post-increment count when admitted, or nil when the limit is reached. The limit is
      # always >= 0 here (the limiter is deactivated in Ruby for negative limits).
      def try_acquire(key, limit, _logger)
        @mutex.synchronize do
          current = @data[key] || 0
          return nil if current >= limit

          @data[key] = current + 1
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

      def try_increment?(user_guid)
        # A negative (or unset) blocking limit means the limiter is deactivated: do nothing,
        # never touch Redis.
        return true unless @blocking_limit&.>=(0)

        key = "#{key_prefix}:#{user_guid}"
        count = store.try_acquire(key, @blocking_limit, @logger)

        return false if count.nil?

        if @logging_limit&.>=(0) && count > @logging_limit
          @logger.info("Concurrency limit warning for user '#{user_guid}', count=#{count} exceeded logging_limit=#{@logging_limit}")
        end

        true
      rescue StoreError
        # fail open
        true
      end

      def decrement(user_guid)
        return unless @blocking_limit&.>=(0)

        key = "#{key_prefix}:#{user_guid}"
        store.decrement(key, @logger)
      rescue StoreError
        # fail open
      end

      def suggested_retry_after
        rand(1..5).to_i
      end

      def error_name
        'ConcurrentRequestLimitExceeded'
      end

      def error_name_ip_based
        'IPBasedConcurrentRequestLimitExceeded'
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
      end

      def call(env)
        user_guid = nil
        incremented = false

        if apply_rate_limiting?(env)
          user_guid = get_user_id(env)
          incremented = @concurrency_limiter.try_increment?(user_guid)
          return too_many_requests!(env) unless incremented
        end

        status, headers, body = @app.call(env)
        [status, headers, body]
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

      def too_many_requests!(env)
        headers = {}
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
