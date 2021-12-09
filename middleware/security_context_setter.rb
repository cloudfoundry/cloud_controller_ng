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
          env['cf.user_guid'] = id_from_token
          env['cf.user_name'] = VCAP::CloudController::SecurityContext.token['user_name']
        end

        status, headers, body = @app.call(env)

        # Return a 401 if the token is invalid and if the rate limit is already exceeded
        if status == 429 && VCAP::CloudController::SecurityContext.invalid_token? && !VCAP::CloudController::SecurityContext.missing_token?
          return invalid_token!(env, headers)
        end

        headers['X-USER-GUID'] = env['cf.user_guid'] if env['cf.user_guid']

        return [status, headers, body]
      rescue VCAP::CloudController::UaaUnavailable => e
        logger.error("Failed communicating with UAA: #{e.message}")
        [502, { 'Content-Type:' => 'application/json' }, [error_message(env, 'UaaUnavailable')]]
      end

      private

      def id_from_token
        VCAP::CloudController::SecurityContext.token['user_id'] || VCAP::CloudController::SecurityContext.token['client_id']
      end

      def error_message(env, error_name)
        api_error = CloudController::Errors::ApiError.new_from_details(error_name)
        error_presenter = if VCAP::Request.api_version == VCAP::Request::API_VERSION_V3
                            ErrorPresenter.new(api_error, Rails.env.test?, V3ErrorHasher.new(api_error))
                          else
                            ErrorPresenter.new(api_error, Rails.env.test?)
                          end
        error_presenter.to_json
      end

      def invalid_token!(env, headers)
        headers['Content-Type']   = 'application/json'
        message                   = error_message(env, 'InvalidAuthToken')
        headers['Content-Length'] = message.length.to_s
        [401, headers, [message]]
      end

      def logger
        @logger = Steno.logger('cc.security_context_setter')
      end
    end
  end
end
