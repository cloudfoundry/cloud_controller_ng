require 'repositories/task_event_repository'

module VCAP::CloudController
  class TaskCancel
    class InvalidCancel < StandardError; end

    def initialize(config)
      @config = config
    end

    def cancel(task:, user_audit_info:)
      reject_invalid_states!(task)

      TaskModel.db.transaction do
        task.lock!
        task.update(state: TaskModel::CANCELING_STATE)

        task_event_repository.record_task_cancel(task, user_audit_info)
      end

      bbs_task_client.cancel_task(task.guid)
    end

    private

    attr_reader :config

    def reject_invalid_states!(task)
      if task.state == TaskModel::SUCCEEDED_STATE || task.state == TaskModel::FAILED_STATE
        raise InvalidCancel.new("Task state is #{task.state} and therefore cannot be canceled")
      end
    end

    def bbs_task_client
      CloudController::DependencyLocator.instance.bbs_task_client
    end

    def task_event_repository
      Repositories::TaskEventRepository.new
    end
  end
end
