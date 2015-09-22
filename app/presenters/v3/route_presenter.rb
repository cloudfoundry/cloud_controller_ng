module VCAP::CloudController
  class RoutePresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(route)
      MultiJson.dump(route_hash(route), pretty: true)
    end

    def present_json_list(paginated_result, base_url)
      routes      = paginated_result.records
      route_hashes = routes.collect { |route| route_hash(route) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, base_url),
        resources:  route_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    def route_hash(route)
      {
        guid:   route.guid,
        host:   route.host,
        path:   route.path,
        created_at: route.created_at,
        updated_at: route.updated_at,
        links: build_links(route),
      }
    end

    def build_links(route)
      {
        space: { href: "/v2/spaces/#{route.space.guid}" },
        domain: { href: "/v2/domains/#{route.domain.guid}" },
      }
    end
  end
end
