require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  class ProcessPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(process)
      MultiJson.dump(process_hash(process), pretty: true)
    end

    def present_json_list(paginated_result, base_url)
      processes      = paginated_result.records
      process_hashes = processes.collect { |app| process_hash(app) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, base_url),
        resources:  process_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    def build_links(process)
      {
        self:  { href: "/v3/processes/#{process.guid}" },
        scale: { href: "/v3/processes/#{process.guid}/scale", 'method' => 'PUT', },
        app:   { href: "/v3/apps/#{process.app_guid}" },
        space: { href: "/v2/spaces/#{process.space_guid}" },
      }
    end

    def process_hash(process)
      {
        guid:         process.guid,
        type:         process.type,
        command:      process.command,
        instances:    process.instances,
        memory_in_mb: process.memory,
        disk_in_mb:   process.disk_quota,
        created_at:   process.created_at,
        updated_at:   process.updated_at,
        links:        build_links(process),
      }
    end
  end
end
