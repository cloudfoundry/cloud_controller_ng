module VCAP::CloudController
  module Repositories
    module Services
      class EventRepository

        def initialize(security_context)
          @user = security_context.current_user
          @current_user_email = security_context.current_user_email
        end

        def record_service_plan_visibility_event(type, visibility, params)
          actee = {
            actee: visibility.guid,
            actee_type: 'service_plan_visibility',
            actee_name: ''
          }
          metadata = {
            service_plan_guid: visibility.service_plan_guid
          }
          space_data = {
            space_guid: '',
            organization_guid: visibility.organization_guid
          }

          create_event("audit.service_plan_visibility.#{type}", user_actor, actee, metadata, space_data)
        end

        def record_broker_event(type, broker, params)
          metadata = metadata_for_broker_params(params)
          actee = {
            actee: broker.guid,
            actee_type: 'broker',
            actee_name: broker.name,
          }
          create_event("audit.service_broker.#{type}", user_actor, actee, metadata)
        end

        def record_service_event(type, service)
          broker = service.service_broker
          actee = {
            actee: service.guid,
            actee_type: 'service',
            actee_name: service.label,
          }
          create_event("audit.service.#{type}", broker_actor(broker), actee, {})
        end

        def record_service_plan_event(type, plan)
          broker = plan.service.service_broker

          actee = {
            actee: plan.guid,
            actee_type: 'service_plan',
            actee_name: plan.name,
          }
          create_event("audit.service_plan.#{type}", broker_actor(broker), actee, {})
        end

        def record_service_dashboard_client_event(type, client_attrs, broker)
          metadata = {
            changes_from_broker_catalog: {}
          }

          if client_attrs.has_key?('redirect_uri')
            metadata[:changes_from_broker_catalog] = {
              secret: '[REDACTED]',
              redirect_uri: client_attrs['redirect_uri']
            }
          end

          actee = {
            actee: client_attrs['id'],
            actee_type: 'service_dashboard_client',
            actee_name: client_attrs['id']
          }
          create_event("audit.service_dashboard_client.#{type}", broker_actor(broker), actee, metadata)
        end

        def record_service_instance_event(type, service_instance, params)
          actee = {
            actee: service_instance.guid,
            actee_type: 'service_instance',
            actee_name: service_instance.name,
          }
          space_data = {space: service_instance.space}
          create_event("audit.service_instance.#{type}", user_actor, actee, { request: params }, space_data)
        end

        def record_user_provided_service_instance_event(type, service_instance, params)
          actee = {
            actee: service_instance.guid,
            actee_type: 'user_provided_service_instance',
            actee_name: service_instance.name,
          }

          metadata = { request: params.dup }
          if params.has_key?('credentials')
            metadata[:request]['credentials'] = "[REDACTED]"
          end

          create_event("audit.user_provided_service_instance.#{type}", user_actor, actee, metadata, { space: service_instance.space })
        end

        def record_service_binding_event(type, service_binding, params=nil)
          metadata = {
            request: {
              service_instance_guid: service_binding.service_instance.guid,
              app_guid: service_binding.app.guid
            }
          }

          actee = {
            actee: service_binding.guid,
            actee_type: 'service_binding',
            actee_name: 'N/A',
          }
          space_data = {space: service_binding.space}
          create_event("audit.service_binding.#{type}", user_actor, actee, metadata, space_data)
        end

        def with_service_event(service, &saveBlock)
          actee = {
            actee_type: "service",
            actee_name: service.label,
          }
          actor = broker_actor(service.service_broker)
          with_audit_event(service, actor, actee, :changes_from_broker_catalog, &saveBlock)
        end

        def with_service_plan_event(plan, &saveBlock)
          actee = {
            actee_type: "service_plan",
            actee_name: plan.name,
          }
          actor = broker_actor(plan.service.service_broker)
          with_audit_event(plan, actor, actee, :changes_from_broker_catalog, &saveBlock)
        end

        def record_service_purge_event(service)
          metadata = {
            request: {
              purge: true
            }
          }
          actee = {
            actee: service.guid,
            actee_type: 'service',
            actee_name: service.label,
          }
          create_event('audit.service.delete', user_actor, actee, metadata)
        end

        private

        def event_type(object, object_type)
          if object.new?
            "audit.#{object_type}.create"
          else
            "audit.#{object_type}.update"
          end
        end

        def metadata_for_broker_params(params)
          request_hash = {}
          [:name, :broker_url, :auth_username].each do |key|
            request_hash[key] = params[key] unless params[key].nil?
          end
          request_hash[:auth_password] = '[REDACTED]' if params.has_key? :auth_password

          metadata = {}
          if request_hash.length > 0
            metadata[:request] = request_hash
          end
          metadata
        end

        def changes_for_modified_model(model_instance)
          changes = {}
          model_instance.to_hash.each do |key, value|
            if model_instance.new? || model_instance.modified?(key.to_sym)
              changes[key.to_s] = value
            end
          end
          changes
        end

        def with_audit_event(object, actor, actee, changes_key, &saveBlock)
          type = event_type(object, actee[:actee_type])
          metadata = {
            changes_key => changes_for_modified_model(object)
          }
          result = saveBlock.call

          actee[:actee] = object.guid
          create_event(type, actor, actee, metadata)
          result
        end

        def broker_actor(broker)
          {
            actor_type: 'service_broker',
            actor: broker.guid,
            actor_name: broker.name
          }
        end

        def user_actor
          {
            actor_type: 'user',
            actor: @user.guid,
            actor_name: @current_user_email
          }
        end

        def create_event(type, actor_data, actee_data, metadata, space_data=nil)
          base_data = {
            type: type,
            timestamp: Time.now,
            metadata: metadata
          }

          unless space_data
            space_data = {
              space_guid: '',
              organization_guid: ''
            }
          end

          data = base_data.merge(actor_data).merge(actee_data).merge(space_data)

          Event.create(data)
        end
      end
    end
  end
end
