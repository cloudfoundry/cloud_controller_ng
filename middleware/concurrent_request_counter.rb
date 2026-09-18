require 'digest'

module CloudFoundry
  module Middleware
    class StoreError < StandardError; end

    class ConcurrentRequestCounter
      @instances = {}
      @mutex = Mutex.new

      def self.instance(key_prefix, **opts)
        return @instances[key_prefix] if @instances[key_prefix]

        @mutex.synchronize do
          @instances[key_prefix] ||= new(key_prefix, **opts)
        end
        @instances[key_prefix]
      end

      def initialize(key_prefix, blocking_limit: nil, logging_limit: nil, redis_connection_pool_size: nil, redis_counter_ttl_seconds: nil)
        @key_prefix = key_prefix
        @blocking_limit = blocking_limit
        @logging_limit = logging_limit
        @redis_connection_pool_size = redis_connection_pool_size
        @redis_counter_ttl_seconds = redis_counter_ttl_seconds
      end

      def try_increment?(user_guid, logger)
        return true unless blocking_active? || logging_active?

        key = "#{@key_prefix}:#{user_guid}"

        if blocking_active?
          count = store.try_increment(key, @blocking_limit, logger)
          return false if count.nil?
        else
          count = store.try_log_increment(key, logger)
          logger.info("Concurrency limit warning for '#{user_guid}', count=#{count} exceeded logging_limit=#{@logging_limit}") if count > @logging_limit
        end

        true
      rescue StoreError
        # fail open
        true
      end

      def decrement(user_guid, logger)
        return unless blocking_active? || logging_active?

        key = "#{@key_prefix}:#{user_guid}"
        store.decrement(key, logger)
      rescue StoreError
        # fail open
      end

      private

      def blocking_active?
        @blocking_limit&.>=(0)
      end

      def logging_active?
        @logging_limit&.>=(0)
      end

      def store
        return @store if defined?(@store)

        redis_socket = VCAP::CloudController::Config.config.get(:redis, :socket)
        @store = if redis_socket.nil?
                   InMemoryStore.new
                 else
                   RedisStore.new(redis_socket, @redis_connection_pool_size, @redis_counter_ttl_seconds)
                 end
      end

      class RedisStore
        # Atomic check-then-increment: admitted when under limit, -1 when rejected (not incremented).
        # KEYS[1] = counter key
        # ARGV[1] = limit (>= 0): 0 rejects all, N caps at N
        # ARGV[2] = ttl in seconds (<= 0 = no expiry)
        INCREMENT_SCRIPT = <<~LUA.freeze
          local limit = tonumber(ARGV[1])
          local ttl = tonumber(ARGV[2])
          local current = tonumber(redis.call('get', KEYS[1]) or '0')
          if current >= limit then
            return -1
          end
          local count = redis.call('incr', KEYS[1])
          if count == 1 and ttl > 0 then
            redis.call('expire', KEYS[1], ttl)
          end
          return count
        LUA
        INCREMENT_SHA = Digest::SHA1.hexdigest(INCREMENT_SCRIPT).freeze

        # Always increments with no cap. Used in logging-only mode to observe real concurrency.
        # KEYS[1] = counter key
        # ARGV[1] = ttl in seconds (<= 0 = no expiry)
        LOG_INCREMENT_SCRIPT = <<~LUA.freeze
          local ttl = tonumber(ARGV[1])
          local count = redis.call('incr', KEYS[1])
          if count == 1 and ttl > 0 then
            redis.call('expire', KEYS[1], ttl)
          end
          return count
        LUA
        LOG_INCREMENT_SHA = Digest::SHA1.hexdigest(LOG_INCREMENT_SCRIPT).freeze

        def initialize(socket, connection_pool_size, counter_ttl_seconds)
          @redis = ConnectionPool::Wrapper.new(size: connection_pool_size) do
            Redis.new(timeout: 1, path: socket)
          end
          @counter_ttl_seconds = counter_ttl_seconds
        end

        # Returns post-increment count when incremented, nil when limit is reached.
        def try_increment(key, limit, logger)
          count = eval_increment(key, limit).to_i
          count.negative? ? nil : count
        rescue Redis::BaseError => e
          logger.error("Redis error: #{e.class} - #{e.message}")
          raise StoreError.new("increment failed: #{e.message}")
        end

        # Always increments and returns count. Used in logging-only mode.
        def try_log_increment(key, logger)
          eval_log_increment(key).to_i
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

        private

        def eval_increment(key, limit)
          argv = [limit, @counter_ttl_seconds || 0]
          @redis.evalsha(INCREMENT_SHA, keys: [key], argv: argv)
        rescue Redis::CommandError => e
          raise unless e.message.include?('NOSCRIPT')

          @redis.eval(INCREMENT_SCRIPT, keys: [key], argv: argv)
        end

        def eval_log_increment(key)
          argv = [@counter_ttl_seconds || 0]
          @redis.evalsha(LOG_INCREMENT_SHA, keys: [key], argv: argv)
        rescue Redis::CommandError => e
          raise unless e.message.include?('NOSCRIPT')

          @redis.eval(LOG_INCREMENT_SCRIPT, keys: [key], argv: argv)
        end
      end

      class InMemoryStore
        def initialize
          @mutex = Mutex.new
          @data = {}
        end

        # Atomic check-and-increment. Returns post-increment count when admitted, nil when at limit.
        def try_increment(key, limit, _logger)
          @mutex.synchronize do
            current = @data[key] || 0
            return nil if current >= limit

            @data[key] = current + 1
          end
        end

        # Always increments and returns count. Never rejects. Used in logging-only mode.
        def try_log_increment(key, _logger)
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
    end
  end
end
