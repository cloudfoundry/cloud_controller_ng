require 'presenters/helpers/censorship'

module VCAP::CloudController
  module Repositories
    class ServiceEventRepository
      attr_reader :user_audit_info

      def initialize(user_audit_info)
        @user_audit_info = user_audit_info
        @with_user_actor = WithUserActor.new(user_audit_info)
        @with_broker_actor = WithBrokerActor.new
      end

      def logger
        Steno.logger('cc.event_repository')
      end

      delegate(
        :record_service_plan_visibility_event,
        :record_service_plan_update_visibility_event,
        :record_service_plan_delete_visibility_event,
        :record_broker_event,
        :record_broker_event_with_request,
        :record_service_instance_event,
        :record_user_provided_service_instance_event,
        :record_service_key_event,
        :record_service_delete_event,
        :record_service_purge_event,
        :record_service_plan_delete_event,
        to: :with_user_actor,
      )

      delegate(
        :record_service_event,
        :record_service_plan_event,
        :record_service_dashboard_client_event,
        :with_service_event,
        :with_service_plan_event,
        to: :with_broker_actor,
      )

      private

      attr_reader :with_broker_actor, :with_user_actor

      module EventCreationHelper
        private

        def logger
          Steno.logger('cc.event_repository')
        end

        def create_event(type, actor_data, actee_data, metadata, space_data=nil)
          base_data = {
            type:      type,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            metadata:  metadata
          }

          space_data ||= {
            space_guid:        '',
            organization_guid: ''
          }

          data = base_data.merge(actor_data).merge(actee_data).merge(space_data)

          begin
            Event.create(data)
          rescue => e
            logger.error("Failed to create audit event: #{e.message}")
          end
        end
      end

      class WithUserActor
        include EventCreationHelper

        def initialize(user_audit_info)
          @user_audit_info = user_audit_info
        end

        def record_service_plan_visibility_event(type, visibility, params)
          space_data = {
            space_guid:        '',
            organization_guid: visibility.organization_guid
          }
          record_plan_visibility_event(type, visibility.guid, params, space_data)
        end

        def record_service_plan_update_visibility_event(plan, params)
          record_plan_visibility_event(:update, plan.guid, params)
        end

        def record_service_plan_delete_visibility_event(plan, org)
          space_data = {
            space_guid: '',
            organization_guid: org.guid
          }
          record_plan_visibility_event(:delete, plan.guid, {}, space_data)
        end

        def record_broker_event(type, broker, params)
          metadata = metadata_for_broker_params(params)
          actee    = {
            actee:      broker.guid,
            actee_type: 'service_broker',
            actee_name: broker.name,
          }
          create_event("audit.service_broker.#{type}", user_actor, actee, metadata)
        end

        def record_broker_event_with_request(type, broker, request)
          metadata = { request: request }
          actee    = {
            actee:      broker.guid,
            actee_type: 'service_broker',
            actee_name: broker.name,
          }
          create_event("audit.service_broker.#{type}", user_actor, actee, metadata)
        end

        def record_service_instance_event(event, service_instance, params=nil)
          metadata = { request: with_parameters_redacted(params) }

          create_service_instance_event(
            'service_instance',
            event,
            service_instance,
            metadata
          )
        end

        def record_user_provided_service_instance_event(event, service_instance, params=nil)
          metadata = { request: with_credentials_redacted(params) }

          create_service_instance_event(
            'user_provided_service_instance',
            event,
            service_instance,
            metadata
          )
        end

        def record_service_key_event(type, service_key, params=nil)
          metadata = { request: {} }

          unless type == :delete
            metadata[:request][:service_instance_guid] = service_key.service_instance.guid
            metadata[:request][:name]                  = service_key.name
          end

          actee = {
            actee:      service_key.guid,
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
            actee:      service.guid,
            actee_type: 'service',
            actee_name: service.label,
          }
          create_event('audit.service.delete', user_actor, actee, metadata)
        end

        def record_service_delete_event(service)
          metadata = { request: {} }
          actee = {
            actee:      service.guid,
            actee_type: 'service',
            actee_name: service.label,
          }
          create_event('audit.service.delete', user_actor, actee, metadata)
        end

        def record_service_plan_delete_event(plan)
          metadata = { request: {} }
          actee = {
            actee:      plan.guid,
            actee_type: 'service_plan',
            actee_name: plan.name,
          }
          create_event('audit.service_plan.delete', user_actor, actee, metadata)
        end

        private

        attr_reader :user_audit_info

        def record_plan_visibility_event(type, actee_guid, params, space_data=nil)
          actee = {
            actee:      actee_guid,
            actee_type: 'service_plan_visibility',
            actee_name: ''
          }

          metadata = { request: params }

          create_event("audit.service_plan_visibility.#{type}", user_actor, actee, metadata, space_data)
        end

        def with_parameters_redacted(request_data)
          redact(request_data, for_key: 'parameters', with: Presenters::Censorship::PRIVATE_DATA_HIDDEN)
        end

        def with_credentials_redacted(request_data)
          redact(request_data, for_key: 'credentials', with: Presenters::Censorship::REDACTED)
        end

        def redact(
          params,
          for_key:,
          with:
        )
          return params unless params.respond_to? :[]=
          return params unless params.key?(for_key)

          params.dup.tap do |p|
            p[for_key] = with
          end
        end

        def metadata_for_broker_params(params)
          request_hash = {}
          [:name, :broker_url, :auth_username, :space_guid].each do |key|
            request_hash[key] = params[key] unless params[key].nil?
          end
          request_hash[:auth_password] = Presenters::Censorship::REDACTED if params.key? :auth_password

          metadata = { request: {} }
          if !request_hash.empty?
            metadata[:request] = request_hash
          end
          metadata
        end

        def create_service_instance_event(type, event, service_instance, metadata)
          actee = {
            actee:      service_instance.guid,
            actee_type: type,
            actee_name: service_instance.name,
          }

          space_data = { space: service_instance.space }

          create_event("audit.#{type}.#{event}", user_actor, actee, metadata, space_data)
        end

        def user_actor
          {
            actor_type:     'user',
            actor:          user_audit_info.user_guid,
            actor_name:     user_audit_info.user_email,
            actor_username: user_audit_info.user_name
          }
        end
      end

      class WithBrokerActor
        include EventCreationHelper

        def record_service_event(type, service)
          broker = service.service_broker
          actee  = {
            actee:      service.guid,
            actee_type: 'service',
            actee_name: service.label,
          }
          create_event("audit.service.#{type}", broker_actor(broker), actee, {})
        end

        def record_service_plan_event(type, plan)
          broker = plan.service_broker

          actee = {
            actee:      plan.guid,
            actee_type: 'service_plan',
            actee_name: plan.name,
          }
          create_event("audit.service_plan.#{type}", broker_actor(broker), actee, {})
        end

        def record_service_dashboard_client_event(type, client_attrs, broker)
          metadata = {}
          if client_attrs.key?('redirect_uri')
            metadata = {
              secret:       Presenters::Censorship::REDACTED,
              redirect_uri: client_attrs['redirect_uri'],
            }
          end

          actee = {
            actee:      client_attrs['id'],
            actee_type: 'service_dashboard_client',
            actee_name: client_attrs['id']
          }

          create_event("audit.service_dashboard_client.#{type}", broker_actor(broker), actee, metadata)
        end

        def with_service_event(service, &save_block)
          actee = {
            actee_type: 'service',
            actee_name: service.label,
          }
          actor = broker_actor(service.service_broker)
          with_audit_event(service, actor, actee, &save_block)
        end

        def with_service_plan_event(plan, &save_block)
          actee = {
            actee_type: 'service_plan',
            actee_name: plan.name,
          }
          actor = broker_actor(plan.service_broker)
          with_audit_event(plan, actor, actee, &save_block)
        end

        private

        def broker_actor(broker)
          {
            actor_type:     'service_broker',
            actor:          broker.guid,
            actor_name:     broker.name,
            actor_username: '',
          }
        end

        def with_audit_event(object, actor, actee)
          type     = event_type(object, actee[:actee_type])
          metadata = changes_for_modified_model(object)
          result   = yield

          actee[:actee] = object.guid
          create_event(type, actor, actee, metadata)
          result
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

        def event_type(object, object_type)
          if object.new?
            "audit.#{object_type}.create"
          else
            "audit.#{object_type}.update"
          end
        end
      end
    end
  end
end
