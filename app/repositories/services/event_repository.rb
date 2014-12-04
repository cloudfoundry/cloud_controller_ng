module VCAP::CloudController
  module Repositories
    module Services
      class EventRepository

        def initialize(security_context)
          @user = security_context.current_user
          @current_user_email = security_context.current_user_email
        end

        def with_service_event(service, &saveBlock)
          actee = {
            type: "service",
            name: service.label,
          }
          with_audit_event(service, actee, :changes_from_broker_catalog, &saveBlock)
        end

        def with_service_plan_event(plan, &saveBlock)
          actee = {
            type: "service_plan",
            name: plan.name,
          }
          with_audit_event(plan, actee, :changes_from_broker_catalog, &saveBlock)
        end

        def create_service_instance_event(type, service_instance, params)
          actee = {
            id: service_instance.guid,
            type: 'service_instance',
            name: service_instance.name,
            space: service_instance.space,
          }
          create_event(type, actee, { request: params })
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

        def create_service_binding_event(type, service_binding, params=nil)
          metadata = {
            request: {
              service_instance_guid: service_binding.service_instance.guid,
              app_guid: service_binding.app.guid
            }
          }

          actee = {
            id: service_binding.guid,
            type: 'service_binding',
            name: 'N/A',
            space: service_binding.space,
          }
          create_event(type, actee, metadata)
        end

        def create_service_dashboard_client_event(type, client_attrs)
          metadata = {
            changes_from_broker_catalog: client_attrs.reject {|key, _| key == 'id' }
          }

          actee = {
            id: client_attrs['id'],
            type: 'service_dashboard_client',
            name: client_attrs['id']
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

        def changes_for_modified_model(model_instance)
          changes = {}
          model_instance.to_hash.each do |key, value|
            if model_instance.new? || model_instance.modified?(key.to_sym)
              changes[key.to_s] = value
            end
          end
          changes
        end

        def with_audit_event(object, actee, changes_key, &saveBlock)
          type = event_type(object, actee[:type])
          metadata = {
            changes_key => changes_for_modified_model(object)
          }
          result = saveBlock.call

          actee[:id] = object.guid
          create_event(type, actee, metadata)
          result
        end

        def create_event(type, actee, metadata)
          base_data = {
            type: type,
            actor_type: 'user',
            actor: @user.guid,
            actor_name: @current_user_email,
            timestamp: Time.now,
            actee: actee.fetch(:id),
            actee_type: actee.fetch(:type),
            actee_name: actee.fetch(:name),
            metadata: metadata,
          }

          if actee[:space]
            space_data = {
              space: actee[:space]
            }
          else
            space_data = {
              space_guid: '',
              organization_guid: ''
            }
          end


          Event.create(base_data.merge(space_data))
        end
      end
    end
  end
end
