require 'presenters/v3/base_presenter'
require 'models/helpers/health_check_types'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class ProcessPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        class << self
          # :labels and :annotations come from MetadataPresentationHelpers
          def associated_resources
            super
          end
        end

        def to_hash
          health_check_data = { timeout: process.health_check_timeout, invocation_timeout: process.health_check_invocation_timeout }
          health_check_data[:endpoint] = process.health_check_http_endpoint if process.health_check_type == HealthCheckTypes::HTTP
          {
            guid:         process.guid,
            created_at:   process.created_at,
            updated_at:   process.updated_at,
            type:         process.type,
            command:      redact(process.specified_or_detected_command),
            instances:    process.instances,
            memory_in_mb: process.memory,
            disk_in_mb:   process.disk_quota,
            health_check: {
              type: process.health_check_type,
              data: health_check_data
            },
            relationships: {
              app: { data: { guid: process.app_guid } },
              revision:     revision,
            },
            metadata: {
              labels: hashified_labels(process.labels),
              annotations: hashified_annotations(process.annotations),
            },
            links:        build_links,
          }
        end

        private

        def revision
          process.revision_guid && {
            data: {
              guid: process.revision_guid
            }
          }
        end

        def process
          @resource
        end

        def build_links
          {
            self:  { href: url_builder.build_url(path: "/v3/processes/#{process.guid}") },
            scale: { href: url_builder.build_url(path: "/v3/processes/#{process.guid}/actions/scale"), method: 'POST', },
            app:   { href: url_builder.build_url(path: "/v3/apps/#{process.app_guid}") },
            space: { href: url_builder.build_url(path: "/v3/spaces/#{process.space_guid}") },
            stats: { href: url_builder.build_url(path: "/v3/processes/#{process.guid}/stats") }
          }
        end
      end
    end
  end
end
