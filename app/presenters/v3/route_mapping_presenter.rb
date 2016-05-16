require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  class RouteMappingPresenter
    attr_reader :route_mapping

    def initialize(route_mapping, show_secrets: true)
      @route_mapping = route_mapping
    end

    def to_hash
      {
        guid:       route_mapping.guid,
        created_at: route_mapping.created_at,
        updated_at: route_mapping.updated_at,
        links:      build_links
      }
    end

    private

    def build_links
      process_link = nil
      unless route_mapping.process_type.blank?
        process_link = { href: "/v3/apps/#{route_mapping.app.guid}/processes/#{route_mapping.process_type}" }
      end

      {
        self:    { href: "/v3/route_mappings/#{route_mapping.guid}" },
        app:     { href: "/v3/apps/#{route_mapping.app.guid}" },
        route:   { href: "/v2/routes/#{route_mapping.route.guid}" },
        process: process_link
      }
    end
  end
end
