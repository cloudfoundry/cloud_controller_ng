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

        process = nil

        RouteMapping.db.transaction do
          process = delete_route_from_process(route_mapping)

          event_repository.record_unmap_route(
            route_mapping.app,
            route_mapping.route,
            @user.try(:guid),
            @user_email,
            route_mapping: route_mapping
          )

          route_mapping.destroy
        end

        notify_dea_of_route_changes(process)
      end
    end

    private

    def delete_route_from_process(route_mapping)
      process = route_mapping.app.processes.find { |p| p.type = route_mapping.process_type }
      unless process.nil?
        process.remove_route(route_mapping.route)
      end
      process
    end

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
