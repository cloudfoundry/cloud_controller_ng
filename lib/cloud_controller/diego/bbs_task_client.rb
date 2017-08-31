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

        handle_diego_errors do
          response = client.desire_task(task_guid: task_guid, task_definition: task_definition, domain: domain)
          logger.info('task.response', task_guid: task_guid, error: response.error)
          response
        end

        nil
      end

      def cancel_task(guid)
        logger.info('cancel.task.request', task_guid: guid)

        handle_diego_errors(acceptable_errors: [::Diego::Bbs::Models::Error::Type::ResourceNotFound]) do
          response = client.cancel_task(guid)
          logger.info('cancel.task.response', task_guid: guid, error: response.error)
          response
        end
      end

      def fetch_task(guid)
        logger.info('fetch.task.request')

        handle_diego_errors(acceptable_errors: [::Diego::Bbs::Models::Error::Type::ResourceNotFound]) do
          response = client.task_by_guid(guid)
          logger.info('fetch.task.response', error: response.error)
          response
        end.task
      end

      def fetch_tasks
        logger.info('fetch.tasks.request')

        handle_diego_errors do
          response = client.tasks(domain: TASKS_DOMAIN)
          logger.info('fetch.tasks.response', error: response.error)
          response
        end.tasks
      end

      def bump_freshness
        logger.info('bump.freshness.request')

        handle_diego_errors do
          response = @client.upsert_domain(domain: TASKS_DOMAIN, ttl: TASKS_DOMAIN_TTL)
          logger.info('bump.freshness.response', error: response.error)
          response
        end
      end

      private

      attr_reader :client

      def handle_diego_errors(acceptable_errors: [])
        begin
          response = yield
        rescue ::Diego::Error => e
          raise CloudController::Errors::ApiError.new_from_details('TaskWorkersUnavailable', e)
        end

        if response.error
          if acceptable_errors.include?(response.error.type)
            response.error = nil
          else
            raise CloudController::Errors::ApiError.new_from_details('TaskError', response.error.message)
          end
        end

        response
      end

      def logger
        @logger ||= Steno.logger('cc.bbs.task_client')
      end
    end
  end
end
