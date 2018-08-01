module VCAP::CloudController
  class TaskFetcher
    def fetch_for_app(task_guid:, app_guid:)
      app = AppModel.where(guid: app_guid).eager(
        :space,
        space: :organization
      ).all.first

      return nil unless app

      task = app.tasks_dataset.where(guid: task_guid).first

      [task, app, app.space, app.organization]
    end

    def fetch(task_guid:)
      task = TaskModel.where(guid: task_guid).eager(
        :space,
        space: :organization
      ).all.first

      return nil unless task
      [task, task.space, task.space.organization]
    end
  end
end
