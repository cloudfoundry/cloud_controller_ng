module VCAP::CloudController
  module Repositories
    module Services
      class EventRepository

        def initialize(security_context)
          @security_context = security_context
        end

        def with_service_event(service, &saveBlock)
          actee = {
            type: "service",
            name: service.label,
          }
          with_audit_event(service, actee, &saveBlock)
        end

        def with_service_plan_event(plan, &saveBlock)
          actee = {
            type: "service_plan",
            name: plan.name,
          }
          with_audit_event(plan, actee, &saveBlock)
        end

        def create_delete_service_event(service, metadata={})
          actee = {
            id: service.guid,
            type: 'service',
            name: service.label,
          }
          create_event('audit.service.delete', actee, metadata)
        end

        def create_delete_service_plan_event(plan)
          actee = {
            id: plan.guid,
            type: 'service_plan',
            name: plan.name,
          }
          create_event('audit.service_plan.delete', actee, {})
        end

        def create_broker_event(type, broker, params)
          metadata = metadata_for_broker_params(params)
          actee = {
            id: broker.guid,
            type: 'broker',
            name: broker.name,
          }
          create_event(type, actee, metadata)
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

        def metadata_for_modified_model(model_instance)
          changes = {}
          model_instance.to_hash.each do |key, value|
            if model_instance.new? || model_instance.modified?(key.to_sym)
              changes[key.to_s] = value
            end
          end

          { changes_from_catalog: changes }
        end

        def with_audit_event(object, actee, &saveBlock)
          type = event_type(object, actee[:type])
          metadata = metadata_for_modified_model(object)
          saveBlock.call

          actee[:id] = object.guid
          create_event(type, actee, metadata)
        end

        def create_event(type, actee, metadata)
          user = @security_context.current_user

          Event.create(
            type: type,
            actor_type: 'user',
            actor: user.guid,
            actor_name: @security_context.current_user_email,
            timestamp: Time.now,
            actee: actee[:id],
            actee_type: actee[:type],
            actee_name: actee[:name],
            space_guid: '',  #empty since services don't associate to spaces
            organization_guid: '',
            metadata: metadata,
          )
        end
      end
    end
  end
end
