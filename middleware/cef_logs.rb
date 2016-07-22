module CloudFoundry
  module Middleware
    class CefLogs
      CEF_VERSION = 0
      SEVERITY    = 0

      def initialize(app, logger, external_ip)
        @app         = app
        @logger      = logger
        @external_ip = escape_extension(external_ip)
      end

      def call(env)
        status, headers, body = @app.call(env)

        request      = ActionDispatch::Request.new(env)
        signature_id = "#{request.method} #{request.path}"
        name         = signature_id

        auth_method, user_guid, user_name = get_auth_info(env, request)

        @logger.info(
          "CEF:#{CEF_VERSION}|cloud_foundry|cloud_controller_ng|#{VCAP::CloudController::Constants::API_VERSION}|" \
          "#{escape_prefix(signature_id)}|#{escape_prefix(name)}|#{SEVERITY}|" \
          "rt=#{(Time.now.utc.to_f * 1000).to_i} " \
          "suser=#{escape_extension(user_name)} " \
          "suid=#{escape_extension(user_guid)} " \
          "request=#{escape_extension(request.filtered_path)} "\
          "requestMethod=#{escape_extension(request.method)} " \
          "src=#{escape_extension(client_ip(request))} dst=#{@external_ip} " \
          "cs1Label=userAuthenticationMechanism cs1=#{auth_method} " \
          "cs2Label=vcapRequestId cs2=#{escape_extension(env['cf.request_id'])} " \
          "cs3Label=result cs3=#{get_result(status)} " \
          "cs4Label=httpStatusCode cs4=#{status} " \
          "cs5Label=xForwardedFor cs5=#{escape_extension(request.headers['HTTP_X_FORWARDED_FOR'])}" \
        )

        [status, headers, body]
      end

      def get_auth_info(env, request)
        if request.authorization.present?
          auth = Rack::Auth::Basic::Request.new(env)
          if auth.basic?
            auth_method = 'basic-auth'
            user_name   = auth.username
            user_guid   = nil
          else
            auth_method = 'oauth-access-token'
            user_name   = env['cf.user_name']
            user_guid   = env['cf.user_guid']
          end
        else
          auth_method = 'no-auth'
          user_name   = nil
          user_guid   = nil
        end

        [auth_method, user_guid, user_name]
      end

      def get_result(status)
        case status.to_s
        when /1\d\d/
          'info'
        when /2\d\d/
          'success'
        when /3\d\d/
          'redirect'
        when /4\d\d/
          'clientError'
        when /5\d\d/
          'serverError'
        end
      end

      private

      # When the request is proxied by another
      # server like HAProxy or Nginx, the IP address that made the original
      # request will be put in an X-Forwarded-For header
      def client_ip(request)
        request.headers.fetch('HTTP_X_FORWARDED_FOR', '').strip.split(/,\s*/).first ||
          request.ip
      end

      def escape_extension(text)
        return '' if text.nil?
        # https://www.ruby-forum.com/topic/143645
        text.gsub('\\', '\\\\\\\\').gsub('=', '\=')
      end

      def escape_prefix(text)
        return '' if text.nil?
        # https://www.ruby-forum.com/topic/143645
        text.gsub('\\', '\\\\\\\\').gsub('|', '\|')
      end
    end
  end
end
