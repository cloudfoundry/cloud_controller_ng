module VCAP::CloudController
  module Repositories
    class ServiceInstanceShareEventRepository
      class << self
        def record_share_event(service_instance, target_space_guids, user_audit_info)
          Event.create(
            type:              'audit.service_instance.share',
            actor:             user_audit_info.user_guid,
            actor_type:        'user',
            actor_name:        user_audit_info.user_email,
            actor_username:    user_audit_info.user_name,
            actee:             service_instance.guid,
            actee_type:        'service_instance',
            actee_name:        service_instance.name,
            timestamp:         Sequel::CURRENT_TIMESTAMP,
            metadata:          {
              target_space_guids: target_space_guids
            },
            space_guid:        service_instance.space.guid,
            organization_guid: service_instance.space.organization.guid,
          )
        end

        def record_unshare_event(service_instance, target_space_guid, user_audit_info)
          Event.create(
            type:              'audit.service_instance.unshare',
            actor:             user_audit_info.user_guid,
            actor_type:        'user',
            actor_name:        user_audit_info.user_email,
            actor_username:    user_audit_info.user_name,
            actee:             service_instance.guid,
            actee_type:        'service_instance',
            actee_name:        service_instance.name,
            timestamp:         Sequel::CURRENT_TIMESTAMP,
            metadata:          {
              target_space_guid: target_space_guid
            },
            space_guid:        service_instance.space.guid,
            organization_guid: service_instance.space.organization.guid,
          )
        end
      end
    end
  end
end
