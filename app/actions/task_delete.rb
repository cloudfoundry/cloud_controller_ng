module VCAP::CloudController
  class TaskDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete_for_app(guid)
      TaskModel.where(app_guid: guid).exclude(state: TaskModel::TERMINAL_STATES).each do |task|
        cancel_running_task(task)
        task.destroy # needs to be done individually due to the 'after_destroy' hook
      end

      TaskModel.where(app_guid: guid).delete
    end

    private

    def cancel_running_task(task)
      return unless task.state == TaskModel::RUNNING_STATE

      Repositories::TaskEventRepository.new.record_task_cancel(task, @user_audit_info)

      begin
        bbs_task_client.cancel_task(task.guid)
      rescue StandardError => e
        logger.error("failed to send cancel task request for task '#{task.guid}': #{e.message}")
        # we want to continue deleting tasks, the backend will become eventually consistent and cancel
        # tasks that no longer exist in ccdb.
      end
    end

    def bbs_task_client
      CloudController::DependencyLocator.instance.bbs_task_client
    end

    def logger
      @logger ||= Steno.logger('cc.task_delete')
    end
  end
end
