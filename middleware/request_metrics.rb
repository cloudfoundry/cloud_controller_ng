module CloudFoundry
  module Middleware
    class RequestMetrics
      def initialize(app, request_metrics)
        @request_metrics = request_metrics
        @app = app
      end

      def call(env)
        @request_metrics.start_request

        status, headers, body = @app.call(env)

        @request_metrics.complete_request(status)

        [status, headers, body]
      end
    end
  end
end
