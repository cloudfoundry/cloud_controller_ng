require 'diego/client'
require 'cloud_controller/diego/constants'

module VCAP::CloudController
  module Diego
    class BbsStagerClient
      ACCEPTABLE_DIEGO_ERRORS = [
        ::Diego::Bbs::ErrorTypes::ResourceNotFound,
      ].freeze

      def initialize(client, config)
        @client = client
        @config = config
      end

      def stage(staging_guid, staging_details)
        logger.info('stage.request', staging_guid: staging_guid)

        staging_message = task_recipe_builder.build_staging_task(@config, staging_details)

        begin
          response = client.desire_task(task_guid: staging_guid, task_definition: staging_message, domain: STAGING_DOMAIN)
        rescue ::Diego::Error => e
          raise CloudController::Errors::ApiError.new_from_details('StagerUnavailable', e)
        end

        logger.info('stage.response', staging_guid: staging_guid, error: response.error)

        if response.error
          raise CloudController::Errors::ApiError.new_from_details('StagerError', "bbs stager client staging failed: #{response.error.message}")
        end

        nil
      end

      def stop_staging(staging_guid)
        logger.info('stop.staging.request', staging_guid: staging_guid)

        begin
          response = client.cancel_task(staging_guid)
        rescue ::Diego::Error => e
          raise CloudController::Errors::ApiError.new_from_details('StagerUnavailable', e)
        end

        logger.info('stop.staging.response', staging_guid: staging_guid, error: response.error)

        if response.error && !ACCEPTABLE_DIEGO_ERRORS.include?(response.error.type)
          raise CloudController::Errors::ApiError.new_from_details('StagerError', "stop staging failed: #{response.error.message}")
        end

        nil
      end

      private

      attr_reader :client

      def logger
        @logger ||= Steno.logger('cc.bbs.stager_client')
      end

      def task_recipe_builder
        @task_recipe_builder ||= TaskRecipeBuilder.new
      end
    end
  end
end
