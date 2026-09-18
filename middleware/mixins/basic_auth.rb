module CloudFoundry
  module Middleware
    module BasicAuth
      private

      def basic_auth?(env)
        auth = Rack::Auth::Basic::Request.new(env)
        auth.provided? && auth.basic?
      end
    end
  end
end
