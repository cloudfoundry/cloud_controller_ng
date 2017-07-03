require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'

module VCAP::CloudController
  class AppCrashedController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    post '/internal/apps/:process_guid/crashed', :crashed_with_auth
    def crashed_with_auth(process_guid)
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise CloudController::Errors::NotAuthenticated
      end
      crashed(process_guid)
    end

    post '/internal/v4/apps/:process_guid/crashed', :crashed
    def crashed(process_guid)
      crash_payload = crashed_request

      app_guid = Diego::ProcessGuid.app_guid(process_guid)

      process = ProcessModel.find(guid: app_guid)
      raise CloudController::Errors::NotFound.new_from_details('ProcessNotFound', app_guid) unless process
      raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'AppCrashed', 'not a diego app') unless process.diego?

      crash_payload['version'] = Diego::ProcessGuid.app_version(process_guid)

      Repositories::ProcessEventRepository.record_crash(process, crash_payload)
      Repositories::AppEventRepository.new.create_app_exit_event(process, crash_payload)
    end

    private

    def crashed_request
      crashed = {}
      begin
        payload = body.read
        crashed = MultiJson.load(payload)
      rescue MultiJson::ParseError => pe
        logger.error('diego.app_crashed.parse-error', payload: payload, error: pe.to_s)
        raise CloudController::Errors::ApiError.new_from_details('MessageParseError', payload)
      end

      crashed
    end
  end
end
