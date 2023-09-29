require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class TaskPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def to_hash
          hide_secrets({
                         guid: task.guid,
                         created_at: task.created_at,
                         updated_at: task.updated_at,
                         sequence_id: task.sequence_id,
                         name: task.name,
                         command: task.command,
                         state: task.state,
                         memory_in_mb: task.memory_in_mb,
                         disk_in_mb: task.disk_in_mb,
                         log_rate_limit_in_bytes_per_second: task.log_rate_limit,
                         result: { failure_reason: task.failure_reason },
                         droplet_guid: task.droplet_guid,
                         relationships: { app: { data: { guid: task.app_guid } } },
                         metadata: {
                           labels: hashified_labels(task.labels),
                           annotations: hashified_annotations(task.annotations)
                         },
                         links: build_links
                       })
        end

        private

        def task
          @resource
        end

        def build_links
          {
            self: { href: url_builder.build_url(path: "/v3/tasks/#{task.guid}") },
            app: { href: url_builder.build_url(path: "/v3/apps/#{task.app_guid}") },
            cancel: { href: url_builder.build_url(path: "/v3/tasks/#{task.guid}/actions/cancel"), method: 'POST' },
            droplet: { href: url_builder.build_url(path: "/v3/droplets/#{task.droplet_guid}") }
          }
        end

        def hide_secrets(hash)
          hash.delete(:command) unless @show_secrets
          hash
        end
      end
    end
  end
end
