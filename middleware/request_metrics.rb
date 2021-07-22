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

        [status, headers, body]
      # in case of e.g. DB exceptions which are not being caught, make sure the metric is being decreased
      rescue => e
        status = 500
        raise e
      ensure
        @request_metrics.complete_request(status)
      end
    end
  end
end
