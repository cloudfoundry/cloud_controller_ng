require 'ipaddr'

module CloudFoundry
  module Middleware
    class RequestLogs
      def initialize(app, logger)
        @app = app
        @logger = logger
      end

      def anonymize_ip(request_ip)
        # Remove last octet of ip if EU GDPR compliance is needed
        ip = IPAddr.new(request_ip) rescue nil
        if VCAP::CloudController::Config.config.get(:logging, :anonymize_ips) && ip.nil?.!
          if ip.ipv4?
            ip.to_string.split('.')[0...-1].join('.') + '.0'
          else
            ip.to_string.split(':')[0...-5].join(':') + ':0000:0000:0000:0000:0000'
          end
        else
          ip.to_string rescue request_ip
        end
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        @logger.info(
          sprintf('Started %<method>s "%<path>s" for user: %<user>s, ip: %<ip>s with vcap-request-id: %<request_id>s at %<at>s',
            method: request.request_method,
            path: request.filtered_path,
            user: env['cf.user_guid'],
            ip: anonymize_ip(request.ip),
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
