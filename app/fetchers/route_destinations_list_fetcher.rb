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
      if @message.requested?(:guids)
        dataset = dataset.where(guid: @message.guids)
      end

      if @message.requested?(:app_guids)
        dataset = dataset.where(app_guid: @message.app_guids)
      end

      dataset
    end
  end
end
