module VCAP::CloudController
  class RouteMappingDelete
    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
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
            @user.try(:guid),
            @user_email,
            route_mapping: route_mapping
          )

          route_mapping.destroy
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
