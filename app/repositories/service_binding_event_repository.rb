require 'repositories/mixins/app_manifest_event_mixins'
require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class ServiceBindingEventRepository
      extend AppManifestEventMixins

      class << self
        def record_start_create(service_binding, user_audit_info, request, manifest_triggered: false)
          attrs = censor_request_attributes(request)

          record_event(
            type: EventTypes::SERVICE_BINDING_START_CREATE,
            service_binding: service_binding,
            user_audit_info: user_audit_info,
            metadata: add_manifest_triggered(manifest_triggered, { request: attrs })
          )
        end

        def record_create(service_binding, user_audit_info, request, manifest_triggered: false)
          attrs = censor_request_attributes(request)

          record_event(
            type: EventTypes::SERVICE_BINDING_CREATE,
            service_binding: service_binding,
            user_audit_info: user_audit_info,
            metadata: add_manifest_triggered(manifest_triggered, { request: attrs })
          )
        end

        def record_start_delete(service_binding, user_audit_info)
          record_event(
            type: EventTypes::SERVICE_BINDING_START_DELETE,
            service_binding: service_binding,
            user_audit_info: user_audit_info,
            metadata: {
              request: {
                app_guid: service_binding.app_guid,
                service_instance_guid: service_binding.service_instance_guid
              }
            }
          )
        end

        def record_delete(service_binding, user_audit_info)
          record_event(
            type: EventTypes::SERVICE_BINDING_DELETE,
            service_binding: service_binding,
            user_audit_info: user_audit_info,
            metadata: {
              request: {
                app_guid: service_binding.app_guid,
                service_instance_guid: service_binding.service_instance_guid
              }
            }
          )
        end

        private

        def censor_request_attributes(request)
          attrs         = request.dup.stringify_keys
          attrs['data'] = Presenters::Censorship::PRIVATE_DATA_HIDDEN if attrs.key?('data')
          attrs
        end

        def record_event(type:, service_binding:, user_audit_info:, metadata: {})
          Event.create(
            type: type,
            actor: user_audit_info.user_guid,
            actor_type: 'user',
            actor_name: user_audit_info.user_email,
            actor_username: user_audit_info.user_name,
            actee: service_binding.guid,
            actee_type: 'service_binding',
            actee_name: service_binding.name || '',
            space_guid: service_binding.space.guid,
            organization_guid: service_binding.space.organization.guid,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            metadata: metadata
          )
        end
      end
    end
  end
end
