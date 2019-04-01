require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'

module VCAP::CloudController
  class AppCrashedController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    post '/internal/v4/apps/:process_guid/crashed', :crashed
    def crashed(process_guid)
      crash_payload = crashed_request

      app_guid = Diego::ProcessGuid.cc_process_guid(process_guid)

      process = ProcessModel.find(guid: app_guid)
      raise CloudController::Errors::NotFound.new_from_details('ProcessNotFound', app_guid) unless process

      crash_payload['version'] = Diego::ProcessGuid.cc_process_version(process_guid)

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
