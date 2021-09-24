require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    InMemoryRequestCount = Struct.new(:valid_until, :requests)

    class RequestCounter
      include Singleton

      def initialize
        @mutex = Mutex.new
        @data = {}
      end

      def get(user_guid, reset_interval_in_minutes, update_db_every_n_requests, logger)
        db_count, valid_until = db_find_or_create(user_guid, reset_interval_in_minutes, logger)
        mem_count = mem_find_or_create(user_guid, valid_until, update_db_every_n_requests)

        [db_count + mem_count, valid_until]
      end

      def increment(user_guid, update_db_every_n_requests)
        db_update_count = mem_increment(user_guid, update_db_every_n_requests)
        db_update(user_guid, { count: Sequel.expr(db_update_count) + :count }) if db_update_count > 0
      end

      private

      def mem_find_or_create(user_guid, valid_until, update_db_every_n_requests)
        return 0 if update_db_every_n_requests == 1

        @mutex.synchronize do
          request_count = @data[user_guid]
          return request_count.requests if request_count&.valid_until == valid_until

          @data[user_guid] = InMemoryRequestCount.new(valid_until, 0)
          return 0
        end
      end

      def mem_increment(user_guid, update_db_every_n_requests)
        return 1 if update_db_every_n_requests == 1

        @mutex.synchronize do
          request_count = @data[user_guid]
          request_count.requests += 1
          return 0 if request_count.requests < update_db_every_n_requests

          db_update_count = request_count.requests
          @data.delete(user_guid)
          return db_update_count
        end
      end

      def db_find_or_create(user_guid, reset_interval_in_minutes, logger)
        request_count = VCAP::CloudController::RequestCount.find_or_create(user_guid: user_guid) do |created_request_count|
          created_request_count.valid_until = Time.now + reset_interval_in_minutes.minutes
        end
        count = request_count.count
        valid_until = request_count.valid_until

        if valid_until < Time.now # expired
          logger.info("Resetting request count of #{count} for user '#{user_guid}'")
          count = 0
          valid_until = Time.now + reset_interval_in_minutes.minutes
          db_update(user_guid, { count: count, valid_until: valid_until })
        end

        [count, valid_until]
      end

      def db_update(user_guid, fields)
        VCAP::CloudController::RequestCount.where(user_guid: user_guid).update(**fields)
      end
    end

    class RateLimiter
      include CloudFoundry::Middleware::ClientIp

      def initialize(app, logger:, general_limit:, unauthenticated_limit:, reset_interval_in_minutes:, update_db_every_n_requests:)
        @app                        = app
        @logger                     = logger
        @general_limit              = general_limit
        @unauthenticated_limit      = unauthenticated_limit
        @reset_interval_in_minutes  = reset_interval_in_minutes
        @update_db_every_n_requests = update_db_every_n_requests
        @request_counter            = RequestCounter.instance
      end

      def call(env)
        rate_limit_headers = {}

        request = ActionDispatch::Request.new(env)

        unless skip_rate_limiting?(env, request)
          user_guid = user_token?(env) ? env['cf.user_guid'] : client_ip(request)

          count, valid_until = @request_counter.get(user_guid, @reset_interval_in_minutes, @update_db_every_n_requests, @logger)

          count += 1

          rate_limit_headers['X-RateLimit-Limit']     = request_limit(env).to_s
          rate_limit_headers['X-RateLimit-Reset']     = valid_until.utc.to_i.to_s
          rate_limit_headers['X-RateLimit-Remaining'] = [0, request_limit(env) - count].max.to_s

          return too_many_requests!(env, rate_limit_headers) if exceeded_rate_limit(count, env)

          @request_counter.increment(user_guid, @update_db_every_n_requests)
        end

        status, headers, body = @app.call(env)
        [status, headers.merge(rate_limit_headers), body]
      end

      private

      def skip_rate_limiting?(env, request)
        auth = Rack::Auth::Basic::Request.new(env)
        basic_auth?(auth) || internal_api?(request) || root_api?(request) || admin?
      end

      def root_api?(request)
        request.fullpath.match(%r{\A(?:/v2/info|/v3|/|/healthz)\z})
      end

      def internal_api?(request)
        request.fullpath.match(%r{\A/internal})
      end

      def basic_auth?(auth)
        (auth.provided? && auth.basic?)
      end

      def user_token?(env)
        !!env['cf.user_guid']
      end

      def request_limit(env)
        @request_limit ||= user_token?(env) ? @general_limit : @unauthenticated_limit
      end

      def too_many_requests!(env, rate_limit_headers)
        rate_limit_headers['Retry-After']    = rate_limit_headers['X-RateLimit-Reset']
        rate_limit_headers['Content-Type']   = 'text/plain; charset=utf-8'
        message                              = rate_limit_error(env).to_json
        rate_limit_headers['Content-Length'] = message.length.to_s
        [429, rate_limit_headers, [message]]
      end

      def rate_limit_error(env)
        error_name = user_token?(env) ? 'RateLimitExceeded' : 'IPBasedRateLimitExceeded'
        api_error = CloudController::Errors::ApiError.new_from_details(error_name)
        version   = env['PATH_INFO'][0..2]
        if version == '/v2'
          ErrorPresenter.new(api_error, Rails.env.test?, V2ErrorHasher.new(api_error)).to_hash
        elsif version == '/v3'
          ErrorPresenter.new(api_error, Rails.env.test?, V3ErrorHasher.new(api_error)).to_hash
        end
      end

      def exceeded_rate_limit(count, env)
        count > request_limit(env)
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end
    end
  end
end
