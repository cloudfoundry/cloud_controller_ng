require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    class RateLimiter
      include CloudFoundry::Middleware::ClientIp

      def initialize(app, logger:, general_limit_enabled:, general_limit:, unauthenticated_limit:, interval:, service_rate_limit_enabled:, service_limit:, service_interval:)
        @app                   = app
        @logger                = logger
        @general_limit_enabled = general_limit_enabled
        @general_limit         = general_limit
        @unauthenticated_limit = unauthenticated_limit
        @interval              = interval
        @service_rate_limit_enabled = service_rate_limit_enabled
        @service_limit         = service_limit
        @service_interval      = service_interval
      end
      # rubocop:disable Metrics/CyclomaticComplexity

      # rubocop:disable Metrics/CyclomaticComplexity
      def call(env)
        rate_limit_headers = {}

        request = ActionDispatch::Request.new(env)
        unless skip_rate_limiting?(env, request)
          user_guid = user_token?(env) ? env['cf.user_guid'] : client_ip(request)
          if @service_rate_limit_enabled && service_instance_request?(request) && rate_limited_methods?(env) && user_token?(env)
            request_count = VCAP::CloudController::RequestCount.find_or_create(user_guid: user_guid) do |created_request_count|
              created_request_count.service_instance_valid_until = Time.now + @service_interval.minutes
            end
            reset_service_instance_request_count(request_count) if reset_service_instance_interval_expired(request_count)
            service_instance_count = request_count.service_instance_count + 1
            rate_limit_headers['X-RateLimit-Limit']     = @service_limit.to_s
            rate_limit_headers['X-RateLimit-Reset']     = request_count.service_instance_valid_until.utc.to_i.to_s
            rate_limit_headers['X-RateLimit-Remaining'] = [0, @service_limit - service_instance_count].max.to_s

            return too_many_requests!(env, rate_limit_headers, true) if exceeded_service_instance_rate_limit(service_instance_count)

            increment_service_instance_request_count!(request_count)
          elsif @general_limit_enabled
            request_count = VCAP::CloudController::RequestCount.find_or_create(user_guid: user_guid) do |created_request_count|
              created_request_count.valid_until = Time.now + @interval.minutes
            end
            reset_request_count(request_count) if reset_interval_expired(request_count)

            count = request_count.count + 1
            rate_limit_headers['X-RateLimit-Limit']     = request_limit(env).to_s
            rate_limit_headers['X-RateLimit-Reset']     = request_count.valid_until.utc.to_i.to_s
            rate_limit_headers['X-RateLimit-Remaining'] = [0, request_limit(env) - count].max.to_s

            return too_many_requests!(env, rate_limit_headers, false) if exceeded_rate_limit(count, env)

            increment_request_count!(request_count)
          end
        end

        status, headers, body = @app.call(env)
        [status, headers.merge(rate_limit_headers), body]
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      private

      def skip_rate_limiting?(env, request)
        auth = Rack::Auth::Basic::Request.new(env)
        basic_auth?(auth) || internal_api?(request) || root_api?(request) || admin?
      end

      def root_api?(request)
        request.fullpath.match(%r{\A(?:/v2/info|/v3|/|/healthz)\z})
      end

      def service_instance_request?(request)
        request.fullpath.match(%r{\A(?:/v2/service_instances|/v3/service_instances)})
      end

      def internal_api?(request)
        request.fullpath.match(%r{\A/internal})
      end

      def rate_limited_methods?(env)
        rate_limit_methods = [
          'PATCH',
          'POST',
          'PUT'
        ]
        if rate_limit_methods.include?env['REQUEST_METHOD']
          return true
        end

        false
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

      def increment_service_instance_request_count!(request_count)
        request_count.update(service_instance_count: Sequel.expr(1) + :service_instance_count)
      end

      def request_limit(env)
        @request_limit ||= user_token?(env) ? @general_limit : @unauthenticated_limit
      end

      def too_many_requests!(env, rate_limit_headers, is_service_call)
        rate_limit_headers['Retry-After']    = rate_limit_headers['X-RateLimit-Reset']
        rate_limit_headers['Content-Type']   = 'text/plain; charset=utf-8'
        message                              = rate_limit_error(env, is_service_call).to_json
        rate_limit_headers['Content-Length'] = message.length.to_s
        [429, rate_limit_headers, [message]]
      end

      def rate_limit_error(env, is_service_call)
        if is_service_call
          error_name = user_token?(env) ? 'ServiceInstanceRateLimitExceeded' : 'IPBasedRateLimitExceeded'
        else
          error_name = user_token?(env) ? 'RateLimitExceeded' : 'IPBasedRateLimitExceeded'
        end
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

      def exceeded_service_instance_rate_limit(service_instance_count)
        service_instance_count > @service_limit
      end

      def reset_interval_expired(request_count)
        if !request_count.valid_until
          return true
        end

        request_count.valid_until < Time.now
      end

      def reset_request_count(request_count)
        @logger.info("Resetting request count of #{request_count.count} for user '#{request_count.user_guid}'")
        request_count.update(valid_until: Time.now + @interval.minutes, count: 0)
      end

      def reset_service_instance_interval_expired(request_count)
        if !request_count.service_instance_valid_until
          return true
        end

        request_count.service_instance_valid_until < Time.now
      end

      def reset_service_instance_request_count(request_count)
        @logger.info("Resetting service instance request count of #{request_count.service_instance_count} for user '#{request_count.user_guid}'")
        request_count.update(service_instance_valid_until: Time.now + @service_interval.minutes, service_instance_count: 0)
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end
    end
  end
end
