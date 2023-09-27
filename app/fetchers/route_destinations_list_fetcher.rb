module VCAP::CloudController
  class RouteDestinationsListFetcher
    def initialize(message:)
      @message = message
    end

    def fetch_for_route(route:)
      filter(route.route_mappings_dataset)
    end

    private

    def filter(dataset)
      dataset = dataset.where(guid: @message.guids) if @message.requested?(:guids)

      dataset = dataset.where(app_guid: @message.app_guids) if @message.requested?(:app_guids)

      dataset
    end
  end
end
