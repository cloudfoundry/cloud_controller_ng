module VCAP::CloudController
  class RouteMappingDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(route_mappings)
      route_mappings = Array(route_mappings)

      route_mappings.each do |route_mapping|
        logger.debug("removing route mapping: #{route_mapping.inspect}")

        route_handler = ProcessRouteHandler.new(route_mapping.process)

        RouteMappingModel.db.transaction do
          event_repository.record_unmap_route(
            route_mapping.app,
            route_mapping.route,
            @user_audit_info,
            route_mapping: route_mapping
          )

          route_mapping.destroy

          begin
            CopilotHandler.new.unmap_route(route_mapping) if Config.config.get(:copilot, :enabled)
          rescue CopilotHandler::CopilotUnavailable => e
            logger.error("failed communicating with copilot backend: #{e.message}")
          end

          route_handler.update_route_information
        end
      end
    end

    private

    def event_repository
      Repositories::AppEventRepository.new
    end

    def logger
      @logger ||= Steno.logger('cc.action.delete_route_mapping')
    end
  end
end
