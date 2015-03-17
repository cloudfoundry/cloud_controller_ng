require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'

module VCAP::CloudController
  class AppCrashedController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise Errors::ApiError.new_from_details('NotAuthenticated')
      end
    end

    post '/internal/apps/:guid/crashed', :crashed

    def crashed(guid)
      crash_payload = crashed_request

      app = App.find(guid: guid)
      raise Errors::ApiError.new_from_details('NotFound') unless app
      raise Errors::ApiError.new_from_details('UnableToPerform', 'AppCrashed', 'not a diego app') unless app.diego?

      Repositories::Runtime::AppEventRepository.new.create_app_exit_event(app, crash_payload)
    end

    private

    def crashed_request
      crashed = {}
      begin
        payload = body.read
        crashed = MultiJson.load(payload)
      rescue MultiJson::ParseError => pe
        logger.error('diego.app_crashed.parse-error', payload: payload, error: pe.to_s)
        raise Errors::ApiError.new_from_details('MessageParseError', payload)
      end

      crashed
    end

  end
end
