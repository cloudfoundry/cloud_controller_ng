require 'cf-copilot'

module VCAP::CloudController
  class RouteHandler
    def initialize(route, runners = nil)
      @route = route

      @runners = runners || CloudController::DependencyLocator.instance.runners
    end

    def update_route_information
      notify_copilot_of_route_update
    end

    def notify_copilot_of_route_update
      logger.info("notifying copilot now")
      copilot_client = CloudController::DependencyLocator.instance.copilot_client
      route_guid = @route.guid
      host = @route.fqdn
      # call copilot sdk
      logger.info("got a copilot client #{copilot_client.inspect}")
      logger.info("upserting route in copilot")
      copilot_client.upsert_route(
          guid: route_guid,
          host: host,
      )
      logger.info("success upserting route in copilot")
    rescue => e
      logger.error("failed communicating with copilot server: #{e.message}")
    end

    private

    def logger
      @logger ||= Steno.logger('cc.process_route_handler')
    end
  end
end
