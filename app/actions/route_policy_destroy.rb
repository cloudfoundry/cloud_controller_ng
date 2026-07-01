require 'repositories/route_policy_event_repository'

module VCAP::CloudController
  class RoutePolicyDestroy
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(route_policy)
      route_policy.destroy
      route_policy.notify_diego

      Repositories::RoutePolicyEventRepository.new.record_route_policy_delete(
        route_policy,
        @user_audit_info
      )

      nil
    end
  end
end
