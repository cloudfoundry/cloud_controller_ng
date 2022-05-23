require 'repositories/route_event_repository'

module VCAP::CloudController
  class RouteUnshare
    class Error < ::StandardError
    end

    def unshare(route, target_space, user_audit_info)
      validate_not_unsharing_from_owner!(route, target_space)

      Route.db.transaction do
        route.remove_shared_space(target_space)
      end
      Repositories::RouteEventRepository.new.record_route_unshare(
        route, user_audit_info, target_space.guid
      )
      route
    end

    private

    def error!(message)
      raise Error.new(message)
    end

    def validate_not_unsharing_from_owner!(route, space)
      if space == route.space
        error!("Unable to unshare route '#{route.uri}' from space '#{route.space.guid}'. Routes cannot be removed from the space that owns them.")
      end
    end
  end
end
