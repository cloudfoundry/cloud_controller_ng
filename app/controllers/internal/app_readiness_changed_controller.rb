require 'sinatra'
require 'controllers/base/base_controller'

module VCAP::CloudController
  class AppReadinessChangedController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    post '/internal/v4/apps/:process_guid/readiness_changed', :readiness_changed
    def readiness_changed(process_guid)
      payload = readiness_request

      app_guid = Diego::ProcessGuid.cc_process_guid(process_guid)

      process = ProcessModel.find(guid: app_guid)
      raise CloudController::Errors::NotFound.new_from_details('ProcessNotFound', app_guid) unless process

      payload['version'] = Diego::ProcessGuid.cc_process_version(process_guid)

      Repositories::ProcessEventRepository.record_readiness_changed(process, payload)

      [200, '{}']
    end

    private

    def readiness_request
      request.body.rewind
      payload = request.body.read
      Oj.load(payload)
    rescue StandardError => e
      logger.error('diego.app_readiness_changed.parse-error', payload: payload, error: e.to_s)
      raise CloudController::Errors::ApiError.new_from_details('MessageParseError', payload)
    end
  end
end
