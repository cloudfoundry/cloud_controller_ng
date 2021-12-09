require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    class RateLimiter
      include CloudFoundry::Middleware::ClientIp

      def initialize(app, logger:, general_limit:, unauthenticated_limit:, interval:)
        @app                   = app
        @logger                = logger
        @general_limit         = general_limit
        @unauthenticated_limit = unauthenticated_limit
        @interval              = interval
      end

      def call(env)
        rate_limit_headers = {}

        request = ActionDispatch::Request.new(env)

        unless skip_rate_limiting?(env, request)
          user_guid = user_token?(env) ? env['cf.user_guid'] : client_ip(request)

          request_count = VCAP::CloudController::RequestCount.find_or_create(user_guid: user_guid) do |created_request_count|
            created_request_count.valid_until = Time.now + @interval.minutes
          end

          reset_request_count(request_count) if reset_interval_expired(request_count)

          count = request_count.count + 1

          rate_limit_headers['X-RateLimit-Limit']     = request_limit(env).to_s
          rate_limit_headers['X-RateLimit-Reset']     = request_count.valid_until.utc.to_i.to_s
          rate_limit_headers['X-RateLimit-Remaining'] = [0, request_limit(env) - count].max.to_s

          return too_many_requests!(env, rate_limit_headers) if exceeded_rate_limit(count, env)

          increment_request_count!(request_count)
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

      def increment_request_count!(request_count)
        request_count.update(count: Sequel.expr(1) + :count)
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
        error_presenter = if VCAP::Request.api_version == VCAP::Request::API_VERSION_V3
                            ErrorPresenter.new(api_error, Rails.env.test?, V3ErrorHasher.new(api_error))
                          else
                            ErrorPresenter.new(api_error, Rails.env.test?)
                          end
        error_presenter.to_hash
      end

      def exceeded_rate_limit(count, env)
        count > request_limit(env)
      end

      def reset_interval_expired(request_count)
        request_count.valid_until < Time.now
      end

      def reset_request_count(request_count)
        @logger.info("Resetting request count of #{request_count.count} for user '#{request_count.user_guid}'")
        request_count.update(valid_until: Time.now + @interval.minutes, count: 0)
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end
    end
  end
end
