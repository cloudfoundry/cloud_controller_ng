require 'sinatra'
require 'controllers/base/base_controller'

module VCAP::CloudController
  class AppReschedulingController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    post '/internal/v4/apps/:process_guid/rescheduling', :rescheduling
    def rescheduling(process_guid)
      rescheduling_payload = rescheduling_request

      app_guid = Diego::ProcessGuid.cc_process_guid(process_guid)

      process = ProcessModel.find(guid: app_guid)
      raise CloudController::Errors::NotFound.new_from_details('ProcessNotFound', app_guid) unless process

      rescheduling_payload['version'] = Diego::ProcessGuid.cc_process_version(process_guid)

      Repositories::ProcessEventRepository.record_rescheduling(process, rescheduling_payload)
    end

    private

    def rescheduling_request
      rescheduling = {}
      begin
        payload = body.read
        rescheduling = MultiJson.load(payload)
      rescue MultiJson::ParseError => pe
        logger.error('diego.app_rescheduling.parse-error', payload: payload, error: pe.to_s)
        raise CloudController::Errors::ApiError.new_from_details('MessageParseError', payload)
      end

      rescheduling
    end
  end
end
