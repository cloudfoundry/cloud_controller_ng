require 'sinatra'
require 'controllers/base/base_controller'

module VCAP::CloudController
  class AppCrashedController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    post '/internal/v4/apps/:process_guid/crashed', :crashed
    def crashed(lrp_process_guid)
      crash_payload = crashed_request

      cc_process_guid = Diego::ProcessGuid.cc_process_guid(lrp_process_guid)

      process = ProcessModel.find(guid: cc_process_guid)
      raise CloudController::Errors::NotFound.new_from_details('ProcessNotFound', cc_process_guid) unless process

      crash_payload['version'] = Diego::ProcessGuid.cc_process_version(lrp_process_guid)

      Repositories::ProcessEventRepository.record_crash(process, crash_payload)
      Repositories::AppEventRepository.new.create_app_crash_event(process.app, crash_payload)

      [200, '{}']
    end

    private

    def crashed_request
      request.body.rewind
      payload = request.body.read
      Oj.load(payload)
    rescue StandardError => e
      logger.error('diego.app_crashed.parse-error', payload: payload, error: e.to_s)
      raise CloudController::Errors::ApiError.new_from_details('MessageParseError', payload)
    end
  end
end
