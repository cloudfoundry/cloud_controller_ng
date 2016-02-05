module VCAP::CloudController
  class TaskCancel

    def cancel(task)
      TaskModel.db.transaction do
        task.lock!
        task.state = TaskModel::CANCELING_STATE
        task.save
      end

      dependency_locator.nsync_client.cancel_task(task)
    end

    private

    def dependency_locator
      CloudController::DependencyLocator.instance
    end
  end
end
