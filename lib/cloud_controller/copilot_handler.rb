require 'cf-copilot'

module VCAP::CloudController
  class CopilotHandler
    def self.create_route(route)
      logger.info("notifying copilot of route creation...")
      copilot_client = CloudController::DependencyLocator.instance.copilot_client
      route_guid = route.guid
      host = route.fqdn
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

    def self.map_route(route_mapping, process)
      logger.info("notifying copilot of route mapping...")
      route = route_mapping.route
      copilot_client = CloudController::DependencyLocator.instance.copilot_client
      route_guid = route.guid
      logger.info("got a copilot client #{copilot_client.inspect}")
      capi_process_guid = process.guid
      diego_process_guid = Diego::ProcessGuid.from_process(process)
      logger.info("mapping route in copilot")
      copilot_client.map_route(
          capi_process_guid: capi_process_guid,
          diego_process_guid: diego_process_guid,
          route_guid: route_guid
      )
      logger.info("success mapping route in copilot")
    rescue => e
      logger.error("failed communicating with copilot server: #{e.message}")
    end

    def self.unmap_route(route_mapping, process)
      logger.info("notifying copilot of route unmapping...")
      route = route_mapping.route
      copilot_client = CloudController::DependencyLocator.instance.copilot_client
      route_guid = route.guid
      logger.info("got a copilot client #{copilot_client.inspect}")
      capi_process_guid = process.guid
      logger.info("unmapping route in copilot")
      copilot_client.unmap_route(
          capi_process_guid: capi_process_guid,
          route_guid: route_guid
      )
      logger.info("success unmapping route in copilot")
    rescue => e
      logger.error("failed communicating with copilot server: #{e.message}")
    end

    def self.delete_route(guid)
      logger.info("notifying copilot of route deletion...")
      copilot_client = CloudController::DependencyLocator.instance.copilot_client
      logger.info("got a copilot client #{copilot_client.inspect}")
      logger.info("deleting route in copilot")
      copilot_client.delete_route(guid: guid)
      logger.info("success deleting route in copilot")
    rescue => e
      logger.error("failed communicating with copilot server: #{e.message}")
    end

    private

    def self.logger
      @logger ||= Steno.logger('cc.copilot_handler')
    end
  end
end
