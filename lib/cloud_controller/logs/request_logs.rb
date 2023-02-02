require 'ipaddr'

module VCAP::CloudController
  module Logs
    class RequestLogs
      def initialize(logger)
        @incomplete_requests = {}
        @logger = logger
      end

      def start_request(request_id, env)
        request = ActionDispatch::Request.new(env)
        return if health_endpoint?(request)

        @logger.info(
          sprintf('Started %<method>s "%<path>s" for user: %<user>s, ip: %<ip>s with vcap-request-id: %<request_id>s at %<at>s',
                  method: request.request_method,
                  path: request.filtered_path,
                  user: env['cf.user_guid'],
                  ip: anonymize_ip(request.ip),
                  request_id: request_id,
                  at: Time.now.utc)
        )
        @incomplete_requests.store(request_id, env)
      end

      def complete_request(request_id, status)
        return if @incomplete_requests.delete(request_id).nil?

        @logger.info("Completed #{status} vcap-request-id: #{request_id}")
      end

      def log_incomplete_requests
        @incomplete_requests.each do |request_id, env|
          request = ActionDispatch::Request.new(env)

          @logger.error(
            sprintf('Incomplete request: %<method>s "%<path>s" for user: %<user>s, ip: %<ip>s with vcap-request-id: %<request_id>s',
                    method: request.request_method,
                    path: request.filtered_path,
                    user: env['cf.user_guid'],
                    ip: anonymize_ip(request.ip),
                    request_id: request_id)
          )
        end
      end

      private

      def health_endpoint?(request)
        request.fullpath.match(%r{\A/healthz})
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
    end
  end
end
