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
      rescue Sequel::DatabaseError => e
        logger.error("Failed to connect to the database: #{e.message}")
        api_error = CloudController::Errors::ApiError.new_from_details('ServiceUnavailable', 'Database connection failure')
        version   = env['PATH_INFO'].to_s[0..2]
        # /v3 gets a V3 error body; everything else (/v2, /internal, /) gets V2 format
        hasher    = version == '/v3' ? V3ErrorHasher.new(api_error) : V2ErrorHasher.new(api_error)
        body      = ErrorPresenter.new(api_error, Rails.env.test?, hasher).to_json
        [503, { 'Content-Type' => 'application/json' }, [body]]
      end

      private

      def logger
        @logger ||= Steno.logger('cc.user_context_setter')
      end
    end
  end
end
