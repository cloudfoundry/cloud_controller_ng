require 'presenters/v3/mixins/redactor'

module VCAP::CloudController
  class TaskPresenter
    include CloudController::Redactor

    attr_reader :task

    def initialize(task, show_secrets: true)
      @task = task
      @show_secrets = show_secrets
    end

    def to_hash
      {
        guid:                  task.guid,
        name:                  task.name,
        command:               redact(task.command, @show_secrets),
        state:                 task.state,
        memory_in_mb:          task.memory_in_mb,
        environment_variables: redact_hash(task.environment_variables || {}, @show_secrets),
        result:                { failure_reason: task.failure_reason },
        created_at:            task.created_at,
        updated_at:            task.updated_at,
        droplet_guid:          task.droplet.guid,
        links:                 build_links
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
