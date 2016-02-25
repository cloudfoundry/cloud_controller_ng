require 'repositories/runtime/task_event_repository'

module VCAP::CloudController
  class TaskCancel
    def cancel(task:, user:, email:)
      TaskModel.db.transaction do
        task.lock!
        task.state = TaskModel::CANCELING_STATE
        task.save

        task_event_repository.record_task_cancel(task, user.guid, email)
      end

      dependency_locator.nsync_client.cancel_task(task)
    end

    private

    def dependency_locator
      CloudController::DependencyLocator.instance
    end

    def task_event_repository
      Repositories::Runtime::TaskEventRepository.new
    end
  end
end
