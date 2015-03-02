module VCAP::CloudController
  module Repositories
    module Runtime
      class SecurityGroupEventRepository
        def record_security_group_delete_request(security_group, actor, actor_name)
          Event.create(
            type: 'audit.security_group.delete-request',
            actee: security_group.guid,
            actee_type: 'security_group',
            actee_name: security_group.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            organization_guid: '',
            space_guid: ''
          )
        end
      end
    end
  end
end
