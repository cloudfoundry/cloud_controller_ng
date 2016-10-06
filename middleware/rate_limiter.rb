module CloudFoundry
  module Middleware
    class RateLimiter
      def initialize(app, default_limit)
        @app = app
        @default_limit = default_limit
      end

      def call(env)
        status, headers, body = @app.call(env)

        headers['X-RateLimit-Limit'] = @default_limit.to_s
        [status, headers, body]
      end
    end
  end
end
