require 'repositories/runtime/task_event_repository'

module VCAP::CloudController
  class TaskCancel
    class InvalidCancel < StandardError; end

    def cancel(task:, user:, email:)
      reject_invalid_states!(task)

      TaskModel.db.transaction do
        task.lock!
        task.state = TaskModel::CANCELING_STATE
        task.save

        task_event_repository.record_task_cancel(task, user.guid, email)
      end

      nsync_client.cancel_task(task)
    end

    private

    def reject_invalid_states!(task)
      if task.state == TaskModel::SUCCEEDED_STATE || task.state == TaskModel::FAILED_STATE
        raise InvalidCancel.new("Task state is #{task.state} and therefore cannot be canceled")
      end
    end

    def nsync_client
      CloudController::DependencyLocator.instance.nsync_client
    end

    def task_event_repository
      Repositories::Runtime::TaskEventRepository.new
    end
  end
end
