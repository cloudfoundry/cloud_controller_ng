require 'cf-copilot'

module VCAP::CloudController
  class CopilotHandler
    def create_route(route)
      logger.info("notifying copilot of route creation...")
      route_guid = route.guid
      host = route.fqdn
      copilot_client.upsert_route(
          guid: route_guid,
          host: host,
          )
      logger.info("success upserting route in copilot")
    rescue => e
      logger.error("failed communicating with copilot server: #{e.message}")
    end

    def map_route(route_mapping)
      logger.info("notifying copilot of route mapping...")
      route = route_mapping.route
      route_guid = route.guid
      capi_process_guid = route_mapping.process.guid
      diego_process_guid = Diego::ProcessGuid.from_process(route_mapping.process)
      copilot_client.map_route(
          capi_process_guid: capi_process_guid,
          diego_process_guid: diego_process_guid,
          route_guid: route_guid
      )
      logger.info("success mapping route in copilot")
    rescue => e
      logger.error("failed communicating with copilot server: #{e.message}")
    end

    def unmap_route(route_mapping)
      logger.info("notifying copilot of route unmapping...")
      route = route_mapping.route
      route_guid = route.guid
      capi_process_guid = route_mapping.process.guid
      copilot_client.unmap_route(
          capi_process_guid: capi_process_guid,
          route_guid: route_guid
      )
      logger.info("success unmapping route in copilot")
    rescue => e
      logger.error("failed communicating with copilot server: #{e.message}")
    end

    def delete_route(guid)
      logger.info("notifying copilot of route deletion...")
      copilot_client.delete_route(guid: guid)
      logger.info("success deleting route in copilot")
    rescue => e
      logger.error("failed communicating with copilot server: #{e.message}")
    end

    private

    def logger
      @logger ||= Steno.logger('cc.copilot_handler')
    end

    def copilot_client
      CloudController::DependencyLocator.instance.copilot_client
    end
  end
end
