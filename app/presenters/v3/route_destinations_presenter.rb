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
          weight: route_mapping.weight
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
  end
end
