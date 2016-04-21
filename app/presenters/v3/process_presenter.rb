require 'presenters/v3/pagination_presenter'
require 'presenters/v3/process_stats_presenter'
require 'cloud_controller/diego/protocol/open_process_ports'

module VCAP::CloudController
  class ProcessPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(process, base_url)
      MultiJson.dump(process_hash(process, base_url), pretty: true)
    end

    def present_json_stats(process, stats)
      response = {
        resources:  ProcessStatsPresenter.new.present_stats_hash(process.type, stats)
      }
      MultiJson.dump(response, pretty: true)
    end

    def present_json_list(paginated_result, base_pagination_url)
      processes      = paginated_result.records
      process_hashes = processes.collect { |app| process_hash(app, nil) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, base_pagination_url),
        resources:  process_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    def build_links(process, base_url)
      base_url ||= "/v3/processes/#{process.guid}"
      {
        self:  { href: "/v3/processes/#{process.guid}" },
        scale: { href: "/v3/processes/#{process.guid}/scale", 'method' => 'PUT', },
        app:   { href: "/v3/apps/#{process.app_guid}" },
        space: { href: "/v2/spaces/#{process.space_guid}" },
        stats: { href: "#{base_url}/stats" }
      }
    end

    def process_hash(process, base_url)
      {
        guid:         process.guid,
        type:         process.type,
        command:      process.command,
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
        links:        build_links(process, base_url),
      }
    end
  end
end
