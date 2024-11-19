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
        start_time = Time.now

        status, headers, body = @app.call(env)
        # convert to milliseconds
        time_taken = (Time.now - start_time) * 1000
        time_taken = time_taken.to_i
        @request_logs.complete_request(request_id, status, env, time_taken)

        [status, headers, body]
      end
    end
  end
end
