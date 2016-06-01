require 'cloud_controller/diego/protocol/open_process_ports'
require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ProcessPresenter < BasePresenter
        def to_hash
          {
            guid:         process.guid,
            type:         process.type,
            command:      redact(process.command),
            instances:    process.instances,
            memory_in_mb: process.memory,
            disk_in_mb:   process.disk_quota,
            ports:        VCAP::CloudController::Diego::Protocol::OpenProcessPorts.new(process).to_a,
            health_check: {
              type: process.health_check_type,
              data: {
                timeout: process.health_check_timeout
              }
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
          {
            self:  { href: "/v3/processes/#{process.guid}" },
            scale: { href: "/v3/processes/#{process.guid}/scale", method: 'PUT', },
            app:   { href: "/v3/apps/#{process.app_guid}" },
            space: { href: "/v2/spaces/#{process.space_guid}" },
            stats: { href: "/v3/processes/#{process.guid}/stats" }
          }
        end
      end
    end
  end
end
