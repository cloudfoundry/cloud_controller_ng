module CloudFoundry
  module Middleware
    class UserContextSetter
      def initialize(app, security_context_configurer)
        @app = app
        @security_context_configurer = security_context_configurer
      end

      def call(env)
        @security_context_configurer.configure_user
        @app.call(env)
      end
    end
  end
end
