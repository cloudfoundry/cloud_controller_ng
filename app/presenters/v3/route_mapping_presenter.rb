require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  class RouteMappingPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(route_mapping)
      MultiJson.dump(route_mapping_hash(route_mapping), pretty: true)
    end

    private

    def route_mapping_hash(route_mapping)
      {
        guid:       route_mapping.guid,
        created_at: route_mapping.created_at,
        updated_at: route_mapping.updated_at,
        links:      build_links(route_mapping)
      }
    end

    def build_links(route_mapping)
      process_link = nil
      unless route_mapping.process_type.blank?
        process_link = { href: "/v3/apps/#{route_mapping.app.guid}/processes/#{route_mapping.process_type}" }
      end

      {
        self:    { href: "/v3/apps/#{route_mapping.app.guid}/route_mappings/#{route_mapping.guid}" },
        app:     { href: "/v3/apps/#{route_mapping.app.guid}" },
        route:   { href: "/v2/routes/#{route_mapping.route.guid}" },
        process: process_link
      }
    end
  end
end
