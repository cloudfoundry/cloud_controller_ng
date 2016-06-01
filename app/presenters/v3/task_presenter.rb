require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class TaskPresenter < BasePresenter
        def to_hash
          {
            guid:                  task.guid,
            name:                  task.name,
            command:               redact(task.command),
            state:                 task.state,
            memory_in_mb:          task.memory_in_mb,
            environment_variables: redact_hash(task.environment_variables || {}),
            result:                { failure_reason: task.failure_reason },
            created_at:            task.created_at,
            updated_at:            task.updated_at,
            droplet_guid:          task.droplet.guid,
            links:                 build_links
          }
        end

        private

        def task
          @resource
        end

        def build_links
          {
            self:    { href: "/v3/tasks/#{task.guid}" },
            app:     { href: "/v3/apps/#{task.app.guid}" },
            droplet: { href: "/v3/droplets/#{task.droplet.guid}" },
          }
        end
      end
    end
  end
end
