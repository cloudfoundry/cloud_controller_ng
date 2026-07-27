require 'repositories/route_policy_event_repository'

module VCAP::CloudController
  class RoutePolicyDestroy
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(route_policy)
      RoutePolicy.db.transaction do
        route_policy.destroy

        Repositories::RoutePolicyEventRepository.new.record_route_policy_delete(
          route_policy,
          @user_audit_info
        )
      end

      route_policy.notify_diego

      nil
    end
  end
end
