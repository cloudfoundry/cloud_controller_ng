module CloudFoundry
  module Middleware
    class RequestLogs
      def initialize(app, logger)
        @app = app
        @logger = logger
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        @logger.info(
          sprintf('Started %s "%s" for %s with vcap-request-id: %s at %s',
            request.request_method,
            request.filtered_path,
            request.ip,
            env['cf.request_id'],
            Time.now.utc)
        )

        status, headers, body = @app.call(env)

        @logger.info("Completed #{status} vcap-request-id: #{env['cf.request_id']}")

        [status, headers, body]
      end
    end
  end
end
