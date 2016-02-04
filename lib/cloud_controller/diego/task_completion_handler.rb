module VCAP::CloudController
  module Diego
    class TaskCompletionHandler
      def complete_task(task, payload)
        begin
          response_parser.validate(payload)
        rescue Membrane::SchemaValidationError => e
          logger.error('failure.invalid-message', task_guid: task.guid, payload: payload, error: e.to_s)
          payload = { failed: true, failure_reason: 'Malformed task response from Diego' }
        end

        task.class.db.transaction do
          task.lock!

          if payload[:failed]
            task.state = TaskModel::FAILED_STATE
            task.failure_reason = payload[:failure_reason]
          else
            task.state = TaskModel::SUCCEEDED_STATE
          end

          task.save_changes(raise_on_save_failure: true)

          app_usage_event_repository.create_from_task(task, 'TASK_STOPPED')
        end
      rescue => e
        logger.error('diego.tasks.saving-failed', task_guid: task.guid, payload: payload, error: e.message)
      end

      private

      def app_usage_event_repository
        Repositories::Runtime::AppUsageEventRepository.new
      end

      def logger
        Steno.logger('cc.tasks')
      end

      def response_parser
        Membrane::SchemaParser.parse do
          {
            failed: bool,
            failure_reason: String,
          }
        end
      end
    end
  end
end
