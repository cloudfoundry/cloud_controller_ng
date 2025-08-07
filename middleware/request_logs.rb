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
        start_timer = timer

        status, headers, body = @app.call(env)
        time_taken_ms = timer - start_timer

        args = [request_id, status, env, time_taken_ms]
        if VCAP::CloudController::Config.config.get(:db, :log_db_queries)
          db_query_metrics = ::VCAP::Request.db_query_metrics
          args += [db_query_metrics.total_query_time_us, db_query_metrics.query_count]
        end
        @request_logs.complete_request(*args)

        [status, headers, body]
      end

      private

      def timer
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      end
    end
  end
end
