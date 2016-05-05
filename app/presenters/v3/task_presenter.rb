module VCAP::CloudController
  class TaskPresenter
    attr_reader :task

    def initialize(task)
      @task = task
    end

    def to_hash
      {
        guid:    task.guid,
        name:    task.name,
        command: task.command,
        state:   task.state,
        memory_in_mb: task.memory_in_mb,
        environment_variables: task.environment_variables || {},
        result: { failure_reason: task.failure_reason },
        created_at: task.created_at,
        updated_at: task.updated_at,
        droplet_guid: task.droplet.guid,
        links: build_links
      }
    end

    private

    def build_links
      {
        self:    { href: "/v3/tasks/#{task.guid}" },
        app:     { href: "/v3/apps/#{task.app.guid}" },
        droplet: { href: "/v3/droplets/#{task.droplet.guid}" },
      }
    end
  end
end
