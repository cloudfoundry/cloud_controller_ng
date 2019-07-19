require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class RouteDestinationsPresenter < BasePresenter
    def to_hash
      {
        destinations: build_destinations,
        links: build_links
      }
    end

    private

    def route
      @resource
    end

    def build_destinations
      route.route_mappings.map do |route_mapping|
        {
          guid: route_mapping.guid,
          app: {
            guid: route_mapping.app_guid,
            process: {
              type: route_mapping.process_type
            }
          },
          weight: route_mapping.weight,
          port: build_port(route_mapping)
        }
      end
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      links = {
        self: {
          href: url_builder.build_url(path: "/v3/routes/#{route.guid}/destinations")
        },
      }

      links[:route] = {
        href: url_builder.build_url(path: "/v3/routes/#{route.guid}")
      }

      links
    end

    def build_port(route_mapping)
      rm_port = route_mapping.app_port

      if rm_port != VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED
        return rm_port
      end

      app_droplet = route_mapping.app.droplet
      if app_droplet && !app_droplet.docker_ports.empty?
        return app_droplet.docker_ports.first
      end

      VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT
    end
  end
end
