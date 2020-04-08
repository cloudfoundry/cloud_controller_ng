require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class RouteDestinationPresenter < BasePresenter
    def to_hash
      {
        guid: destination.guid,
        app: {
          guid: destination.app_guid,
          process: {
            type: destination.process_type
          }
        },
        weight: destination.weight,
        port: destination.presented_port
      }
    end

    private

    def destination
      @resource
    end
  end
end
