require 'mixins/client_ip'
require 'mixins/user_reset_interval'
require 'base_rate_limiter'

module CloudFoundry
  module Middleware
    REQUEST_COUNTER_V2_API = BaseRequestCounter.new

    class RateLimiterV2API < BaseRateLimiter
      def initialize(app, opts)
        @per_process_general_limit = opts[:per_process_general_limit]
        @global_general_limit      = opts[:global_general_limit]
        @per_process_admin_limit   = opts[:per_process_admin_limit]
        @global_admin_limit        = opts[:global_admin_limit]
        super(app, opts[:logger], REQUEST_COUNTER_V2_API, opts[:interval], 'V2-API')
      end

      private

      def skip_rate_limiting?(env, request)
        auth = Rack::Auth::Basic::Request.new(env)
        basic_auth?(auth) || !request.fullpath.match(%r{\A/v2/(?!(info)).+})
      end

      def global_request_limit(env)
        admin? ? @global_admin_limit : @global_general_limit
      end

      def per_process_request_limit(env)
        admin? ? @per_process_admin_limit : @per_process_general_limit
      end

      def rate_limit_error(env)
        error_name = 'RateLimitV2APIExceeded'
        api_error = CloudController::Errors::ApiError.new_from_details(error_name)
        ErrorPresenter.new(api_error, Rails.env.test?, V2ErrorHasher.new(api_error)).to_hash
      end
    end
  end
end
