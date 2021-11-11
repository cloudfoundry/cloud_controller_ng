module CloudFoundry
  module Middleware
    class ServiceBrokerRequestCounter
      include Singleton

      def initialize
        @mutex = Mutex.new
        @data = {}
      end

      def can_make_request?(user_guid, limit)
        @mutex.synchronize do
          request_count = @data.fetch(user_guid, 0)
          return false if request_count + 1 > limit

          @data[user_guid] = request_count + 1
          true
        end
      end

      def decrement(user_guid)
        @mutex.synchronize do
          @data[user_guid] = @data[user_guid] - 1
        end
      end
    end

    class ServiceBrokerRateLimiter
      def initialize(app, logger:, concurrent_limit:)
        @app                               = app
        @logger                            = logger
        @concurrent_limit = concurrent_limit
        @request_counter = ServiceBrokerRequestCounter.instance
      end

      def call(env)
        request = ActionDispatch::Request.new(env)
        user_guid = env['cf.user_guid']

        unless skip_rate_limiting?(env, request)
          return too_many_requests!(env) unless @request_counter.can_make_request?(user_guid, @concurrent_limit)

          begin
            return @app.call(env)
          rescue => e
            raise e
          ensure
            @request_counter.decrement(user_guid)
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
        %w(PATCH PUT POST).include? request.method
      end

      def user_token?(env)
        !!env['cf.user_guid']
      end

      def too_many_requests!(env)
        message = rate_limit_error(env).to_json
        [429, {}, [message]]
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
