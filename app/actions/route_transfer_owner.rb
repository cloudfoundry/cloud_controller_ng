require 'repositories/route_event_repository'

module VCAP::CloudController
  class RouteTransferOwner
    class << self
      def transfer(route, target_space, user_audit_info)
        return route if target_space.name == route.space.name

        original_space = route.space
        Route.db.transaction do
          Route.db.after_commit {
            Repositories::RouteEventRepository.new.record_route_transfer_owner(
              route, user_audit_info, original_space, target_space.guid)
          }
          route.space = target_space
          route.remove_shared_space(target_space)
          route.add_shared_space(original_space)
          route.save
        end
      end
    end
  end
end
