module CloudFoundry
  module Middleware
    RequestCount = Struct.new(:requests, :valid_until)

    class BaseRequestCounter
      include CloudFoundry::Middleware::UserResetInterval

      def initialize
        reset
      end

      # needed for testing
      def reset
        @mutex = Mutex.new
        @data = {}
      end

      def get(user_guid, reset_interval_in_minutes, logger)
        @mutex.synchronize do
          return create_new_request_count(user_guid, reset_interval_in_minutes) unless @data.key? user_guid

          request_count = @data[user_guid]
          if request_count.valid_until < Time.now.utc
            logger.info("Resetting request count of #{request_count.requests} for user '#{user_guid}'")
            return create_new_request_count(user_guid, reset_interval_in_minutes)
          end

          [request_count.requests, request_count.valid_until]
        end
      end

      def increment(user_guid)
        @mutex.synchronize do
          request_count = @data[user_guid]
          request_count.requests += 1
          @data[user_guid] = request_count
        end
      end

      private

      def create_new_request_count(user_guid, reset_interval_in_minutes)
        requests = 0
        valid_until = next_reset_interval(user_guid, reset_interval_in_minutes)
        @data[user_guid] = RequestCount.new(requests, valid_until)
        [requests, valid_until]
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

      def as_hash
        return {} if [@limit, @reset, @remaining].all?(&:nil?)

        { "#{@prefix}-Limit#{@suffix}" => @limit, "#{@prefix}-Reset#{@suffix}" => @reset, "#{@prefix}-Remaining#{@suffix}" => @remaining }
      end
    end

    class BaseRateLimiter
      include CloudFoundry::Middleware::ClientIp

      def initialize(app, logger, request_counter, reset_interval, header_suffix=nil)
        @app = app
        @logger = logger
        @request_counter = request_counter
        @reset_interval = reset_interval
        @header_suffix = header_suffix
      end

      def call(env)
        rate_limit_headers = RateLimitHeaders.new(@header_suffix)

        request = ActionDispatch::Request.new(env)

        unless skip_rate_limiting?(env, request)
          user_guid = user_token?(env) ? env['cf.user_guid'] : client_ip(request)

          count, valid_until = @request_counter.get(user_guid, @reset_interval, @logger)
          new_request_count = count + 1

          rate_limit_headers.limit = global_request_limit(env).to_s
          rate_limit_headers.reset = valid_until.to_i.to_s
          rate_limit_headers.remaining = estimate_remaining(env, new_request_count)

          return too_many_requests!(env, rate_limit_headers) if exceeded_rate_limit(new_request_count, env)

          @request_counter.increment(user_guid)
        end

        status, headers, body = @app.call(env)
        [status, headers.merge(rate_limit_headers.as_hash), body]
      end

      private

      def skip_rate_limiting?(env, request)
        raise NotImplementedError
      end

      def global_request_limit(env)
        raise NotImplementedError
      end

      def rate_limit_error(env)
        raise NotImplementedError
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

      def basic_auth?(auth)
        (auth.provided? && auth.basic?)
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end

      def too_many_requests!(env, rate_limit_headers)
        headers = {}
        headers['Retry-After'] = rate_limit_headers.reset
        headers['Content-Type'] = 'text/plain; charset=utf-8'
        message = rate_limit_error(env).to_json
        headers['Content-Length'] = message.length.to_s
        [429, rate_limit_headers.as_hash.merge(headers), [message]]
      end
    end
  end
end
