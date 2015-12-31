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

    post '/internal/apps/:process_guid/crashed', :crashed

    def crashed(process_guid)
      crash_payload = crashed_request

      app_guid = Diego::ProcessGuid.app_guid(process_guid)

      app = App.find(guid: app_guid)
      raise Errors::ApiError.new_from_details('NotFound') unless app
      raise Errors::ApiError.new_from_details('UnableToPerform', 'AppCrashed', 'not a diego app') unless app.diego?

      crash_payload['version'] = Diego::ProcessGuid.app_version(process_guid)

      app_for_event = app.is_v3? ? app.app : app
      Repositories::Runtime::AppEventRepository.new.create_app_exit_event(app_for_event, crash_payload)
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
