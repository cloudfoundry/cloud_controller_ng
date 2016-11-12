require 'diego/client'
require 'cloud_controller/diego/constants'

module VCAP::CloudController
  module Diego
    class BbsTaskClient
      def desire_task(task_guid, task_definition, domain)
        logger.info('task.request', task_guid: task_guid)

        begin
          response = client.desire_task(task_guid: task_guid, task_definition: task_definition, domain: domain)
        rescue ::Diego::Error => e
          raise CloudController::Errors::ApiError.new_from_details('TaskWorkersUnavailable', e)
        end

        logger.info('task.response', task_guid: task_guid, error: response.error)

        if response.error
          raise CloudController::Errors::ApiError.new_from_details('TaskError', "task failed: #{response.error.message}")
        end

        nil
      end
    end

    class BbsStagingClient
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

      def stop_staging(staging_guid)
        logger.info('stop.staging.request', staging_guid: staging_guid)

        begin
          response = client.cancel_task(staging_guid)
        rescue ::Diego::Error => e
          raise CloudController::Errors::ApiError.new_from_details('StagerUnavailable', e)
        end

        logger.info('stop.staging.response', staging_guid: staging_guid, error: response.error)

        if response.error
          raise CloudController::Errors::ApiError.new_from_details('StagerError', "stop staging failed: #{response.error.message}")
        end

        nil
      end

      private

      attr_reader :client

      def logger
        @logger ||= Steno.logger('cc.bbs.staging-client')
      end
    end
  end
end
