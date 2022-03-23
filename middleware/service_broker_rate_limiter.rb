require 'concurrent-ruby'

module CloudFoundry
  module Middleware
    class ServiceBrokerRequestCounter
      include Singleton

      def initialize
        @data = {}
      end

      def limit=(limit)
        @data.default = Concurrent::Semaphore.new(limit)
      end

      def try_acquire?(user_guid)
        return @data[user_guid].try_acquire
      end

      def release(user_guid)
        @data[user_guid].release
      end
    end

    class ServiceBrokerRateLimiter
      def initialize(app, opts)
        @app                               = app
        @logger                            = opts[:logger]
        @broker_timeout_seconds            = opts[:broker_timeout_seconds]
        @request_counter = ServiceBrokerRequestCounter.instance
      end

      def call(env)
        request = ActionDispatch::Request.new(env)
        user_guid = env['cf.user_guid']

        unless skip_rate_limiting?(env, request)
          return too_many_requests!(env, user_guid) unless @request_counter.try_acquire?(user_guid)

          begin
            return @app.call(env)
          rescue => e
            raise e
          ensure
            @request_counter.release(user_guid)
          end
        end

        @app.call(env)
      end

      private

      def skip_rate_limiting?(env, request)
        return admin? || !is_service_request?(request) || !rate_limit_method?(request)
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end

      def is_service_request?(request)
        [
          %r{\A/v2/service_instances},
          %r{\A/v2/service_bindings},
          %r{\A/v2/service_keys},
          %r{\A/v3/service_instances},
          %r{\A/v3/service_credential_bindings},
          %r{\A/v3/service_route_bindings},
        ].any? { |re| request.fullpath.match re }
      end

      def rate_limit_method?(request)
        %w(PATCH PUT POST DELETE).include? request.method
      end

      def user_token?(env)
        !!env['cf.user_guid']
      end

      def suggested_retry_time
        delay_range = (@broker_timeout_seconds * 0.5).floor..(@broker_timeout_seconds * 1.5).ceil
        Time.now.utc + rand(delay_range).to_i.second
      end

      def too_many_requests!(env, user_guid)
        rate_limit_headers = {}
        rate_limit_headers['Retry-After'] = suggested_retry_time
        @logger.info("Service broker concurrent rate limit exceeded for user '#{user_guid}'")
        message = rate_limit_error(env).to_json
        [429, rate_limit_headers, [message]]
      end

      def rate_limit_error(env)
        error_name = 'ServiceBrokerRateLimitExceeded'
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
