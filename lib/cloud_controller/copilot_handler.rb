require 'cf-copilot'

module VCAP::CloudController
  class CopilotHandler
    class CopilotUnavailable < StandardError; end

    def create_route(route)
      copilot_client.upsert_route(
        guid: route.guid,
        host: route.fqdn
      )
    rescue StandardError => e
      raise CopilotUnavailable.new(e.message)
    end

    def map_route(route_mapping)
      copilot_client.map_route(
        capi_process_guid: route_mapping.process.guid,
        diego_process_guid: Diego::ProcessGuid.from_process(route_mapping.process),
        route_guid: route_mapping.route.guid
      )
    rescue StandardError => e
      raise CopilotUnavailable.new(e.message)
    end

    def unmap_route(route_mapping)
      copilot_client.unmap_route(
        capi_process_guid: route_mapping.process.guid,
        route_guid: route_mapping.route.guid
      )
    rescue StandardError => e
      raise CopilotUnavailable.new(e.message)
    end

    private

    def copilot_client
      @copilot_client ||= CloudController::DependencyLocator.instance.copilot_client
    end
  end
end
