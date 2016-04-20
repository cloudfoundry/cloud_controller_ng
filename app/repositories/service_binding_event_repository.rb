module VCAP::CloudController
  module Repositories
    class ServiceBindingEventRepository
      def self.record_create(service_binding, user_guid, user_email, request)
        attrs = request.dup.stringify_keys
        attrs['data'] = 'PRIVATE DATA HIDDEN' if attrs.key?('data')

        Event.create(
          type:              'audit.service_binding.create',
          actor:             user_guid,
          actor_type:        'user',
          actor_name:        user_email,
          actee:             service_binding.guid,
          actee_type:        'v3-service-binding',
          actee_name:        '',
          space_guid:        service_binding.space.guid,
          organization_guid: service_binding.space.organization.guid,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          { request: attrs }
        )
      end
    end
  end
end
