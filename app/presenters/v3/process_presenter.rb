require 'cloud_controller/diego/protocol/open_process_ports'
require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ProcessPresenter < BasePresenter
        def to_hash
          health_check_data = { timeout: process.health_check_timeout }
          health_check_data[:endpoint] = process.health_check_http_endpoint if process.health_check_type == 'http'
          {
            guid:         process.guid,
            type:         process.type,
            command:      redact(process.command),
            instances:    process.instances,
            memory_in_mb: process.memory,
            disk_in_mb:   process.disk_quota,
            health_check: {
              type: process.health_check_type,
              data: health_check_data
            },
            created_at:   process.created_at,
            updated_at:   process.updated_at,
            links:        build_links
          }
        end

        private

        def process
          @resource
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
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
