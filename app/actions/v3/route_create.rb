module VCAP::CloudController
  module V3
    class RouteCreate
      class << self
        def create_route(route_hash:, logger:, user_audit_info:)
          route = Route.create_from_hash(route_hash)

          begin
            CopilotAdapter.create_route(route) if Config.config.get(:copilot, :enabled)
          rescue CopilotAdapter::CopilotUnavailable => e
            logger.error("failed communicating with copilot backend: #{e.message}")
          end

          Repositories::RouteEventRepository.new.record_route_create(route, user_audit_info, route_hash)

          route
        end
      end
    end
  end
end
