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
          sprintf('Started %<method>s "%<path>s" for user: %<user>s, ip: %<ip>s with vcap-request-id: %<request_id>s at %<at>s',
            method: request.request_method,
            path: request.filtered_path,
            user: env['cf.user_guid'],
            ip: request.ip,
            request_id: env['cf.request_id'],
            at: Time.now.utc)
        )

        status, headers, body = @app.call(env)

        @logger.info("Completed #{status} vcap-request-id: #{env['cf.request_id']}")

        [status, headers, body]
      end
    end
  end
end
