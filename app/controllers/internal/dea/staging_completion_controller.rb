require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'

module VCAP::CloudController
  module Dea
    class StagingCompletionController < RestController::BaseController
      def self.dependencies
        [:stagers]
      end

      allow_unauthenticated_access

      def initialize(*)
        super
        auth = Rack::Auth::Basic::Request.new(env)
        unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
          raise CloudController::Errors::NotAuthenticated
        end
      end

      def inject_dependencies(dependencies)
        super
        @stagers = dependencies.fetch(:stagers)
      end

      post '/internal/dea/staging/:app_guid/completed', :completed

      def completed(app_guid)
        staging_response = read_body

        app = App.find(guid: app_guid)
        raise CloudController::Errors::ApiError.new_from_details('NotFound') unless app

        raise CloudController::Errors::ApiError.new_from_details('InvalidRequest') unless app.staging_task_id == staging_response['task_id']

        begin
          stagers.stager_for_app(app).staging_complete(nil, staging_response)
        rescue CloudController::Errors::ApiError => api_err
          logger.error('dea.staging.completion-controller-error', error: api_err)
          raise CloudController::Errors::ApiError.new_from_details('ServerError', name: api_err.name, message: api_err.message) if api_err.name.eql? 'StagingError'
          return [200, '{}']
        rescue => e
          logger.error('dea.staging.completion-controller-error', error: e)
          raise CloudController::Errors::ApiError.new_from_details('ServerError')
        end

        [200, '{}']
      end

      private

      attr_reader :stagers

      def read_body
        staging_response = {}
        begin
          payload = body.read
          staging_response = MultiJson.load(payload, symbolize_keys: false)
        rescue MultiJson::ParseError => pe
          logger.error('dea.staging.parse-error', payload: payload, error: pe.to_s)
          raise CloudController::Errors::ApiError.new_from_details('MessageParseError', payload)
        end

        staging_response
      end
    end
  end
end
