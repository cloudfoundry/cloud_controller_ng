require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    module UserId
      include CloudFoundry::Middleware::ClientIp

      def get_user_id(env)
        user_token?(env) ? env['cf.user_guid'] : client_ip(ActionDispatch::Request.new(env))
      end

      def user_token?(env)
        !!env['cf.user_guid']
      end
    end
  end
end
