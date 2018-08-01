require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'

module VCAP::CloudController
  module Dea
    class HM9000Controller < RestController::BaseController
      allow_unauthenticated_access

      def initialize(*)
        super
        auth = Rack::Auth::Basic::Request.new(env)
        unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
          raise CloudController::Errors::NotAuthenticated
        end
      end

      post '/internal/dea/hm9000/start/:app_guid', :start

      def start(app_guid)
        raise CloudController::Errors::ApiError.new_from_details('NotFound') unless App.find(guid: app_guid)
        logger.info('dea.hm9000.start', app_guid: app_guid)
        SubSystem.hm9000_respondent.process_hm9000_start(read_body)

        [200, '{}']
      end

      post '/internal/dea/hm9000/stop/:app_guid', :stop

      def stop(app_guid)
        raise CloudController::Errors::ApiError.new_from_details('NotFound') unless App.find(guid: app_guid)
        logger.info('dea.hm9000.stop', app_guid: app_guid)
        SubSystem.hm9000_respondent.process_hm9000_stop(read_body)

        [200, '{}']
      end

      private

      def read_body
        message = {}
        begin
          payload = body.read
          message = MultiJson.load(payload, symbolize_keys: false)
        rescue MultiJson::ParseError => pe
          logger.error('dea.hm9000.parse-error', payload: payload, error: pe.to_s)
          raise CloudController::Errors::ApiError.new_from_details('MessageParseError', payload)
        end

        message
      end
    end
  end
end
