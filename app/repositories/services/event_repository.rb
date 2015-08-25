module VCAP::CloudController
  module Repositories
    module Services
      class EventRepository
        def initialize(user:, user_email:)
          @user = user
          @current_user_email = user_email
        end

        def logger
          Steno.logger('cc.event_repository')
        end

        def record_service_plan_visibility_event(type, visibility, params)
          actee = {
            actee: visibility.guid,
            actee_type: 'service_plan_visibility',
            actee_name: ''
          }

          metadata = { request: params }

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
            actee_type: 'service_broker',
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
          broker = plan.service_broker

          actee = {
            actee: plan.guid,
            actee_type: 'service_plan',
            actee_name: plan.name,
          }
          create_event("audit.service_plan.#{type}", broker_actor(broker), actee, {})
        end

        def record_service_dashboard_client_event(type, client_attrs, broker)
          metadata = {}
          if client_attrs.key?('redirect_uri')
            metadata = {
              secret: '[REDACTED]',
              redirect_uri: client_attrs['redirect_uri'],
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
          space_data = { space: service_instance.space }
          create_event("audit.service_instance.#{type}", user_actor, actee, { request: params }, space_data)
        end

        def record_user_provided_service_instance_event(type, service_instance, params)
          actee = {
            actee: service_instance.guid,
            actee_type: 'user_provided_service_instance',
            actee_name: service_instance.name,
          }

          metadata = { request: params.dup }
          if params.key?('credentials')
            metadata[:request]['credentials'] = '[REDACTED]'
          end

          space_data = { space: service_instance.space }
          create_event("audit.user_provided_service_instance.#{type}", user_actor, actee, metadata, space_data)
        end

        def record_service_binding_event(type, service_binding, params=nil)
          metadata = { request: {} }

          unless type == :delete
            metadata[:request][:service_instance_guid] = service_binding.service_instance.guid
            metadata[:request][:app_guid] = service_binding.app.guid
          end

          actee = {
            actee: service_binding.guid,
            actee_type: 'service_binding',
            actee_name: '',
          }
          space_data = { space: service_binding.space }
          create_event("audit.service_binding.#{type}", user_actor, actee, metadata, space_data)
        end

        def record_service_key_event(type, service_key, params=nil)
          metadata = { request: {} }

          unless type == :delete
            metadata[:request][:service_instance_guid] = service_key.service_instance.guid
            metadata[:request][:name] = service_key.name
          end

          actee = {
              actee: service_key.guid,
              actee_type: 'service_key',
              actee_name: service_key.name,
          }
          space_data = { space: service_key.space }
          create_event("audit.service_key.#{type}", user_actor, actee, metadata, space_data)
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

        def with_service_event(service, &saveBlock)
          actee = {
            actee_type: 'service',
            actee_name: service.label,
          }
          actor = broker_actor(service.service_broker)
          with_audit_event(service, actor, actee, &saveBlock)
        end

        def with_service_plan_event(plan, &saveBlock)
          actee = {
            actee_type: 'service_plan',
            actee_name: plan.name,
          }
          actor = broker_actor(plan.service_broker)
          with_audit_event(plan, actor, actee, &saveBlock)
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
          request_hash[:auth_password] = '[REDACTED]' if params.key? :auth_password

          metadata = { request: {} }
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

        def with_audit_event(object, actor, actee, &saveBlock)
          type = event_type(object, actee[:actee_type])
          metadata = changes_for_modified_model(object)
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
            timestamp: Sequel::CURRENT_TIMESTAMP,
            metadata: metadata
          }

          unless space_data
            space_data = {
              space_guid: '',
              organization_guid: ''
            }
          end

          data = base_data.merge(actor_data).merge(actee_data).merge(space_data)

          begin
            Event.create(data)
          rescue => e
            logger.error("Failed to create audit event: #{e.message}")
          end
        end
      end
    end
  end
end
