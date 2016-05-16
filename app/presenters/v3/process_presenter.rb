require 'presenters/v3/mixins/redactor'
require 'cloud_controller/diego/protocol/open_process_ports'

module VCAP::CloudController
  class ProcessPresenter
    include CloudController::Redactor

    attr_reader :process, :base_url

    def initialize(process, base_url=nil, show_secrets: true)
      @process = process
      @base_url = base_url || "/v3/processes/#{process.guid}"
      @show_secrets = show_secrets
    end

    def to_hash
      {
        guid:         process.guid,
        type:         process.type,
        command:      redact(process.command, @show_secrets),
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

    def build_links
      {
        self:  { href: "/v3/processes/#{process.guid}" },
        scale: { href: "/v3/processes/#{process.guid}/scale", method: 'PUT', },
        app:   { href: "/v3/apps/#{process.app_guid}" },
        space: { href: "/v2/spaces/#{process.space_guid}" },
        stats: { href: "#{base_url}/stats" }
      }
    end
  end
end
