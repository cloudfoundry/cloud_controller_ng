module VCAP::CloudController
  class TaskPresenter
    def present_json(task)
      MultiJson.dump(task_hash(task), pretty: true)
    end

    private

    def task_hash(task)
      {
        guid:    task.guid,
        name:    task.name,
        command: task.command,
        state:   task.state,
        environment_variables:   task.environment_variables || {},
        result:  { failure_reason: task.failure_reason },
        links:   build_links(task)
      }
    end

    def build_links(task)
      {
        self:    { href: "/v3/tasks/#{task.guid}" },
        app:     { href: "/v3/apps/#{task.app.guid}" },
        droplet: { href: "/v3/droplets/#{task.droplet.guid}" },
      }
    end
  end
end
