module CloudFoundry
  module Middleware
    class SecurityContextSetter
      UUID_REGEX = '[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}'.freeze
      UPLOADS_PATH_REGEX = Regexp.union(
        [
          %r{/v3/packages/#{UUID_REGEX}/upload}i.freeze,
          %r{/v3/buildpacks/#{UUID_REGEX}/upload}i.freeze,
          %r{/v3/droplets/#{UUID_REGEX}/upload}i.freeze
        ]
      )

      def initialize(app, security_context_configurer)
        @app                         = app
        @security_context_configurer = security_context_configurer
      end

      def call(env)
        header_token = env['HTTP_AUTHORIZATION']
        request_path = env['REQUEST_PATH']

        security_context_configurer = @security_context_configurer

        if request_path && request_path.match(UPLOADS_PATH_REGEX)
          upload_start_time = Rack::Request.new(env).params['upload_start_time'].to_i
          if upload_start_time
            relaxed_token_decoder = VCAP::CloudController::UaaTokenDecoder.new(VCAP::CloudController::Config.config.get(:uaa), alternate_reference_time: upload_start_time)
            security_context_configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(relaxed_token_decoder)
          end
        end

        security_context_configurer.configure(header_token)

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
        version = env['PATH_INFO'][0..2]

        if version == '/v2'
          ErrorPresenter.new(api_error, Rails.env.test?, V2ErrorHasher.new(api_error)).to_json
        elsif version == '/v3'
          ErrorPresenter.new(api_error, Rails.env.test?, V3ErrorHasher.new(api_error)).to_json
        end
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
