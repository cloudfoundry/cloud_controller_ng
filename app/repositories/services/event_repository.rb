module VCAP::CloudController
  module Repositories
    module Services
      class EventRepository

        def initialize(security_context)
          @security_context = security_context
        end

        def metadata_for_modified_service(service)
          instance_fields = {
            broker_guid: :service_broker_guid,
            unique_id: :broker_provided_id,
            label: :label,
            description: :description,
            bindable: :bindable,
            tags: :tags,
            extra: :extra,
            active: :active,
            requires: :requires,
            plan_updateable: :plan_updateable
          }
          entity = {}
          instance_fields.each do |key, value|
            if service.new? || service.modified?(key)
              entity[key.to_s] = service.send(value)
            end
          end
          { entity: entity }
        end

        def create_service_event(type, service, metadata)
          user = @security_context.current_user

          Event.create(
              type: type,
              actor_type: 'user',
              actor: user.guid,
              actor_name: @security_context.current_user_email,
              timestamp: Time.now,
              actee: service.guid,
              actee_type: 'service',
              actee_name: service.label,
              space_guid: '',  #empty since services don't associate to spaces
              organization_guid: '',
              metadata: metadata,
            )
        end

        def create_service_plan_event(type, plan, metadata)
          user = @security_context.current_user

          Event.create(
              type: type,
              actor_type: 'user',
              actor: user.guid,
              actor_name: @security_context.current_user_email,
              timestamp: Time.now,
              actee: plan.guid,
              actee_type: 'service_plan',
              actee_name: plan.name,
              space_guid: '',  #empty since plans don't associate to spaces
              organization_guid: '',
              metadata: metadata,
            )
        end

        def create_audit_event(type, broker, params)
          user = @security_context.current_user

          request_hash = {}
          [:name, :broker_url, :auth_username].each do |key|
            request_hash[key] = params[key] unless params[key].nil?
          end
          request_hash[:auth_password] = '[REDACTED]' if params.has_key? :auth_password

          metadata = {}
          if request_hash.length > 0
            metadata[:request] = request_hash
          end

          Event.create(
              type: type,
              actor_type: 'user',
              actor: user.guid,
              actor_name: @security_context.current_user_email,
              timestamp: Time.now,
              actee: broker.guid,
              actee_type: 'broker',
              actee_name: broker.name,
              space_guid: '',  #empty since brokers don't associate to spaces
              organization_guid: '',
              metadata: metadata,
            )
        end
      end
    end
  end
end
