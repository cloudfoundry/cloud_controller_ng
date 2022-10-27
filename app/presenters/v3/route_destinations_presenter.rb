require 'presenters/v3/base_presenter'
require 'presenters/v3/route_destination_presenter'

module VCAP::CloudController::Presenters::V3
  class RouteDestinationsPresenter < BasePresenter
    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
      route:
    )
      @route = route
      super(resource, show_secrets: show_secrets, censored_message: censored_message, decorators: [])
    end

    def to_hash
      {
        destinations: presented_destinations,
        links: build_links
      }
    end

    def presented_destinations
      destinations.sort_by(&:guid).map do |route_mapping|
        RouteDestinationPresenter.new(route_mapping).destination_hash
      end
    end

    private

    attr_reader :route

    def destinations
      @resource
    end

    def build_links
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
