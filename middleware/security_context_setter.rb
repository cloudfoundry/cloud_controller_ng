module CloudFoundry
  module Middleware
    class SecurityContextSetter
      def initialize(app, security_context_configurer)
        @app                         = app
        @security_context_configurer = security_context_configurer
      end

      def call(env)
        header_token = env['HTTP_AUTHORIZATION']

        @security_context_configurer.configure(header_token)

        if VCAP::CloudController::SecurityContext.valid_token?
          env['cf.user_guid'] = VCAP::CloudController::SecurityContext.token['user_id']
          env['cf.user_name'] = VCAP::CloudController::SecurityContext.token['user_name']
        end

        @app.call(env)

      rescue VCAP::CloudController::UaaUnavailable => e
        logger.error("Failed communicating with UAA: #{e}")
        [502, {}, []]
      end

      def logger
        @logger = Steno.logger('cc.security_context_setter')
      end
    end
  end
end
