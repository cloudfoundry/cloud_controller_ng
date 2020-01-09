require 'presenters/v3/base_presenter'
require 'presenters/v3/route_destination_presenter'

module VCAP::CloudController::Presenters::V3
  class RouteDestinationsPresenter < BasePresenter
    def to_hash
      {
        destinations: presented_destinations,
        links: build_links
      }
    end

    private

    def route
      @resource
    end

    def presented_destinations
      route.route_mappings.map do |route_mapping|
        RouteDestinationPresenter.new(route_mapping).to_hash
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
