module CloudFoundry
  module Middleware
    module ClientIp
      # When the request is proxied by another
      # server like HAProxy or Nginx, the IP address that made the original
      # request will be put in an X-Forwarded-For header
      def client_ip(request)
        request.headers.fetch('HTTP_X_FORWARDED_FOR', '').strip.split(/,\s*/).first || request.ip
      end
    end
  end
end
