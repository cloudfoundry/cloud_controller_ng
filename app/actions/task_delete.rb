module VCAP::CloudController
  class TaskDelete
    def initialize(user_guid, email)
      @user_guid = user_guid
      @email = email
    end

    def delete(tasks)
      tasks.each do |task|
        task.destroy
        cancel_running_task(task)
      end
    end

    private

    def cancel_running_task(task)
      return unless task.state == TaskModel::RUNNING_STATE
      Repositories::TaskEventRepository.new.record_task_cancel(task, @user_guid, @email)

      begin
        nsync_client.cancel_task(task)
      rescue => e
        logger.error("failed to send cancel task request for task '#{task.guid}': #{e.message}")
        # we want to continue deleting tasks, the backend will become eventually consistent and cancel
        # tasks that no longer exist in ccdb.
      end
    end

    def nsync_client
      CloudController::DependencyLocator.instance.nsync_client
    end

    def logger
      @logger ||= Steno.logger('cc.task_delete')
    end
  end
end
