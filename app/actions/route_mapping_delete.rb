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

        if route_mapping.process
          route_mapping.process.handle_remove_route(route_mapping.route)
        end

        RouteMappingModel.db.transaction do
          event_repository.record_unmap_route(
            route_mapping.app,
            route_mapping.route,
            @user.try(:guid),
            @user_email,
            route_mapping: route_mapping
          )

          route_mapping.destroy
        end

        notify_dea_of_route_changes(route_mapping.process)
      end
    end

    private

    def notify_dea_of_route_changes(process)
      if process && process.dea_update_pending?
        Dea::Client.update_uris(process)
      end
    end

    def event_repository
      Repositories::AppEventRepository.new
    end

    def logger
      @logger ||= Steno.logger('cc.action.delete_route_mapping')
    end
  end
end
