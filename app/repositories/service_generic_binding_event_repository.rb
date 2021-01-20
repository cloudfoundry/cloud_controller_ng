require 'repositories/mixins/app_manifest_event_mixins'

module VCAP::CloudController
  module Repositories
    class ServiceGenericBindingEventRepository
      include AppManifestEventMixins

      SERVICE_APP_CREDENTIAL_BINDING = 'service_binding'.freeze
      SERVICE_KEY_CREDENTIAL_BINDING = 'service_key'.freeze
      SERVICE_ROUTE_BINDING = 'service_route_binding'.freeze

      def initialize(actee_name)
        @actee_name = actee_name
      end

      def record_start_create(service_binding, user_audit_info, request, manifest_triggered: false)
        attrs = censor_request_attributes(request)

        record_event(
          type:            "audit.#{@actee_name}.start_create",
          service_binding: service_binding,
          user_audit_info: user_audit_info,
          metadata:        add_manifest_triggered(manifest_triggered, { request: attrs })
        )
      end

      def record_create(service_binding, user_audit_info, request, manifest_triggered: false)
        attrs = censor_request_attributes(request)

        record_event(
          type:            "audit.#{@actee_name}.create",
          service_binding: service_binding,
          user_audit_info: user_audit_info,
          metadata:        add_manifest_triggered(manifest_triggered, { request: attrs })
        )
      end

      def record_update(service_binding, user_audit_info, request, manifest_triggered: false)
        attrs = censor_request_attributes(request)

        record_event(
          type:            "audit.#{@actee_name}.update",
          service_binding: service_binding,
          user_audit_info: user_audit_info,
          metadata:        add_manifest_triggered(manifest_triggered, { request: attrs })
        )
      end

      def record_start_delete(service_binding, user_audit_info)
        record_event(
          type: "audit.#{@actee_name}.start_delete",
          service_binding: service_binding,
          user_audit_info: user_audit_info,
          metadata: {
            request: {
              app_guid: service_binding.try(:app_guid),
              route_guid: service_binding.try(:route_guid),
              service_instance_guid: service_binding.service_instance_guid,
            }
          }
        )
      end

      def record_delete(service_binding, user_audit_info)
        record_event(
          type: "audit.#{@actee_name}.delete",
          service_binding: service_binding,
          user_audit_info: user_audit_info,
          metadata: {
            request: {
              app_guid: service_binding.try(:app_guid),
              route_guid: service_binding.try(:route_guid),
              service_instance_guid: service_binding.service_instance_guid,
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
        space_guid = service_binding.service_instance.space.guid
        org_guid = service_binding.service_instance.space.organization.guid

        if service_binding.try(:space)
          space_guid = service_binding.space.guid
          org_guid = service_binding.space.organization.guid
        end

        Event.create(
          type:              type,
          actor:             user_audit_info.user_guid,
          actor_type:        'user',
          actor_name:        user_audit_info.user_email,
          actor_username:    user_audit_info.user_name,
          actee:             service_binding.guid,
          actee_type:        @actee_name,
          actee_name:        service_binding.try(:name) || '',
          space_guid:        space_guid,
          organization_guid: org_guid,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          metadata
        )
      end
    end
  end
end
