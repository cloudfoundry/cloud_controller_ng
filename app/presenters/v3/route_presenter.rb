module VCAP::CloudController
  class RoutePresenter
    def present_json(route)
      MultiJson.dump(route_hash(route), pretty: true)
    end

    def present_json_list(routes, base_url)
      route_hashes = routes.collect { |route| route_hash(route) }

      response = {
        resources:  route_hashes
      }

      MultiJson.dump(response, pretty: true)
    end

    private

    def route_hash(route)
      {
        guid:   route.guid,
        host:   route.host,
        _links: build_links(route),
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
