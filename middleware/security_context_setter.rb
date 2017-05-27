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
        logger.error("Failed communicating with UAA: #{e.message}")
        [502, { 'Content-Type:' => 'application/json' }, [error_message(env)]]
      end

      private

      def error_message(env)
        api_error = CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
        version = env['PATH_INFO'][0..2]

        if version == '/v2'
          ErrorPresenter.new(api_error, Rails.env.test?, V2ErrorHasher.new(api_error)).to_json
        elsif version == '/v3'
          ErrorPresenter.new(api_error, Rails.env.test?, V3ErrorHasher.new(api_error)).to_json
        end
      end

      def logger
        @logger = Steno.logger('cc.security_context_setter')
      end
    end
  end
end
