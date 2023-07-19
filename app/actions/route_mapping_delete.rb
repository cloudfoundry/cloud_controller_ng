module VCAP::CloudController
  class RouteMappingDelete
    def initialize(user_audit_info, manifest_triggered: false)
      @user_audit_info = user_audit_info
      @manifest_triggered = manifest_triggered
    end

    def delete(route_mappings)
      route_mappings = Array(route_mappings)

      route_mappings.each do |route_mapping|
        logger.debug("removing route mapping: #{route_mapping.inspect}")

        route_handlers = route_mapping.processes.map do |process|
          ProcessRouteHandler.new(process)
        end

        RouteMappingModel.db.transaction do
          event_repository.record_unmap_route(
            @user_audit_info,
            route_mapping,
            manifest_triggered: @manifest_triggered
          )

          next if RouteMappingModel.find(guid: route_mapping.guid).nil?

          route_mapping.destroy

          route_handlers.each do |handler|
            handler.update_route_information(perform_validation: false)
          end
        end
      end
    end

    private

    def route_resource_manager
      CloudController::DependencyLocator.instance.route_resource_manager
    end

    def event_repository
      Repositories::AppEventRepository.new
    end

    def logger
      @logger ||= Steno.logger('cc.action.delete_route_mapping')
    end
  end
end
