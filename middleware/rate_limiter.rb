module CloudFoundry
  module Middleware
    class RateLimiter
      def initialize(app, default_limit)
        @app = app
        @default_limit = default_limit
      end

      def call(env)
        status, headers, body = @app.call(env)
        if env['cf.user_guid']
          request_count = VCAP::CloudController::RequestCount.find_or_create(user_guid: env['cf.user_guid'])
          request_count.count += 1
          request_count.save

          headers['X-RateLimit-Limit'] = @default_limit.to_s
          headers['X-RateLimit-Remaining'] = [0, @default_limit - request_count.count].max.to_s
        end
        [status, headers, body]
      end
    end
  end
end
