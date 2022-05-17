require 'repositories/route_event_repository'

module VCAP::CloudController
  class RouteShare
    class Error < ::StandardError
    end

    def create(route, target_spaces, user_audit_info)
      validate_not_sharing_to_self!(route, target_spaces)

      Route.db.transaction do
        target_spaces.each do |space|
          route.add_shared_space(space)
        end
      end
      Repositories::RouteEventRepository.new.record_route_share(
        route, user_audit_info, target_spaces.map(&:guid)
      )
      route
    end

    def delete(route, target_space, user_audit_info)
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

    def validate_not_sharing_to_self!(route, spaces)
      if spaces.include?(route.space)
        error!("Unable to share route '#{route.uri}' with space '#{route.space.guid}'. Routes cannot be shared into the space where they were created.")
      end
    end

    def validate_not_unsharing_from_owner!(route, space)
      if space == route.space
        error!("Unable to unshare route '#{route.uri}' from space '#{route.space.guid}'. Routes cannot be removed from the space that owns them.")
      end
    end
  end
end
