module VCAP::CloudController
  class TaskDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
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
      Repositories::AppUsageEventRepository.new.create_from_task(task, 'TASK_STOPPED')
      Repositories::TaskEventRepository.new.record_task_cancel(task, @user_audit_info)

      begin
        if bypass_bridge?
          bbs_task_client.cancel_task(task.guid)
        else
          nsync_client.cancel_task(task)
        end
      rescue => e
        logger.error("failed to send cancel task request for task '#{task.guid}': #{e.message}")
        # we want to continue deleting tasks, the backend will become eventually consistent and cancel
        # tasks that no longer exist in ccdb.
      end
    end

    def bypass_bridge?
      !!HashUtils.dig(Config.config, :diego, :temporary_local_tasks)
    end

    def nsync_client
      CloudController::DependencyLocator.instance.nsync_client
    end

    def bbs_task_client
      CloudController::DependencyLocator.instance.bbs_task_client
    end

    def logger
      @logger ||= Steno.logger('cc.task_delete')
    end
  end
end
