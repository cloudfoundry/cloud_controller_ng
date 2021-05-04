module CloudFoundry
  module Middleware
    class RequestLogs
      def initialize(app, request_logs)
        @request_logs = request_logs
        @app = app
      end

      def call(env)
        request_id = env['cf.request_id']
        @request_logs.start_request(request_id, env)

        status, headers, body = @app.call(env)

        @request_logs.complete_request(request_id, status)

        [status, headers, body]
      end
    end
  end
end
