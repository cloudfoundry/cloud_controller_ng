require 'mixins/client_ip'
require 'mixins/user_reset_interval'
require 'base_rate_limiter'

module CloudFoundry
  module Middleware
    REQUEST_COUNTER = BaseRequestCounter.new

    class RateLimiter < BaseRateLimiter
      def initialize(app, opts)
        @per_process_general_limit         = opts[:per_process_general_limit]
        @global_general_limit              = opts[:global_general_limit]
        @per_process_unauthenticated_limit = opts[:per_process_unauthenticated_limit]
        @global_unauthenticated_limit      = opts[:global_unauthenticated_limit]
        super(app, opts[:logger], REQUEST_COUNTER, opts[:interval])
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

      def global_request_limit(env)
        user_token?(env) ? @global_general_limit : @global_unauthenticated_limit
      end

      def per_process_request_limit(env)
        user_token?(env) ? @per_process_general_limit : @per_process_unauthenticated_limit
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
    end
  end
end
