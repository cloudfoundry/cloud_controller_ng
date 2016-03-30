require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  class RouteMappingPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(route_mapping)
      MultiJson.dump(route_mapping_hash(route_mapping), pretty: true)
    end

    def present_json_list(paginated_result, base_url)
      route_mappings       = paginated_result.records
      route_mapping_hashes = route_mappings.map { |route_mapping| route_mapping_hash(route_mapping) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, base_url),
        resources:  route_mapping_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
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
        self:    { href: "/v3/route_mappings/#{route_mapping.guid}" },
        app:     { href: "/v3/apps/#{route_mapping.app.guid}" },
        route:   { href: "/v2/routes/#{route_mapping.route.guid}" },
        process: process_link
      }
    end
  end
end
