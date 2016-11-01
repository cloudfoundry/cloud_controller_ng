require 'diego/client'
require 'cloud_controller/diego/constants'

module VCAP::CloudController
  module Diego
    class BbsStagerClient
      def initialize(client)
        @client = client
      end

      def stage(staging_guid, staging_message)
        logger.info('stage.request', staging_guid: staging_guid)

        begin
          response = client.desire_task(task_guid: staging_guid, task_definition: staging_message, domain: STAGING_DOMAIN)
        rescue ::Diego::Error => e
          raise CloudController::Errors::ApiError.new_from_details('StagerUnavailable', e)
        end

        logger.info('stage.response', staging_guid: staging_guid, error: response.error)

        if response.error
          raise CloudController::Errors::ApiError.new_from_details('StagerError', "staging failed: #{response.error.message}")
        end

        nil
      end

      private

      attr_reader :client

      def logger
        @logger ||= Steno.logger('cc.stager.client')
      end
    end
  end
end
