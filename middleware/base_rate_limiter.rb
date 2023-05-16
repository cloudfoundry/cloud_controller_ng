require 'mixins/client_ip'
require 'mixins/user_reset_interval'

module CloudFoundry
  module Middleware
    class ExpiringRequestCounter
      include CloudFoundry::Middleware::UserResetInterval

      Counter = Struct.new(:value, :expires_at)

      def initialize(key_prefix)
        @key_prefix = key_prefix
        @mutex = Mutex.new
        @data = {}
      end

      def increment(user_guid, reset_interval_in_minutes, logger)
        key = "#{@key_prefix}:#{user_guid}"
        expires_in = next_expires_in(user_guid, reset_interval_in_minutes)
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
      include CloudFoundry::Middleware::ClientIp

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
          user_guid = user_token?(env) ? env['cf.user_guid'] : client_ip(ActionDispatch::Request.new(env))

          count, expires_in = @expiring_request_counter.increment(user_guid, @reset_interval, @logger)

          rate_limit_headers.limit = global_request_limit(env).to_s
          rate_limit_headers.reset = (Time.now.to_i + expires_in).to_s
          rate_limit_headers.remaining = estimate_remaining(env, count)

          return too_many_requests!(expires_in, env, rate_limit_headers) if exceeded_rate_limit(count, env)
        end

        status, headers, body = @app.call(env)
        [status, headers.merge(rate_limit_headers.to_hash), body]
      end

      private

      def apply_rate_limiting?(env)
        raise 'method should be implemented in concrete class'
      end

      def global_request_limit(env)
        raise 'method should be implemented in concrete class'
      end

      def rate_limit_error(env)
        raise 'method should be implemented in concrete class'
      end

      def per_process_request_limit(env)
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

      def user_token?(env)
        !!env['cf.user_guid']
      end

      def basic_auth?(env)
        auth = Rack::Auth::Basic::Request.new(env)
        auth.provided? && auth.basic?
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end

      def too_many_requests!(expires_in, env, rate_limit_headers)
        headers = {}
        headers['Retry-After'] = expires_in.to_s
        headers['Content-Type'] = 'text/plain; charset=utf-8'
        message = rate_limit_error(env).to_json
        headers['Content-Length'] = message.length.to_s
        [429, rate_limit_headers.to_hash.merge(headers), [message]]
      end
    end
  end
end
