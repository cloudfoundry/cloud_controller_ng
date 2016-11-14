require 'diego/client'
require 'cloud_controller/diego/constants'

module VCAP::CloudController
  module Diego
    class BbsTaskClient
      def initialize(client)
        @client = client
      end

      def desire_task(task_guid, task_definition, domain)
        logger.info('task.request', task_guid: task_guid)

        begin
          response = client.desire_task(task_guid: task_guid, task_definition: task_definition, domain: domain)
        rescue ::Diego::Error => e
          raise CloudController::Errors::ApiError.new_from_details('TaskWorkersUnavailable', e)
        end

        logger.info('task.response', task_guid: task_guid, error: response.error)

        if response.error
          raise CloudController::Errors::ApiError.new_from_details('TaskError', response.error.message)
        end

        nil
      end

      private

      attr_reader :client

      def logger
        @logger ||= Steno.logger('cc.bbs.task_client')
      end
    end
  end
end
