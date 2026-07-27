require 'repositories/route_policy_event_repository'

module VCAP::CloudController
  class RoutePolicyUpdate
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def update(route_policy, message)
      RoutePolicy.db.transaction do
        MetadataUpdate.update(route_policy, message)

        Repositories::RoutePolicyEventRepository.new.record_route_policy_update(
          route_policy,
          @user_audit_info,
          message.audit_hash
        )
      end

      route_policy
    end
  end
end
