# require 'messages/service_instance_update_managed_message'

module VCAP::CloudController
  module V3
    class UpdateServiceInstanceJob < VCAP::CloudController::Jobs::CCJob
      def initialize(service_instance_guid, message:, user_audit_info:)
        super()
        @service_instance_guid = service_instance_guid
        @message = message
        @user_audit_info = user_audit_info
      end

      def perform
        logger = Steno.logger('cc.background')
        logger.info("Updating service instance #{service_instance_guid}")

        gone! if service_instance.nil?

        operation_in_progress = service_instance.last_operation.type
        aborted! if operation_in_progress != 'update'

        client = VCAP::Services::ServiceClientProvider.provide({ instance: service_instance })
        broker_response, err = client.update(
          service_instance,
          service_plan,
          accepts_incomplete: false,
          arbitrary_parameters: message.parameters || {},
          previous_values: previous_values,
          name: message.requested?(:name) ? message.name : service_instance.name,
        )

        if err
          service_instance.save_with_new_operation({}, broker_response[:last_operation])
          raise err
        end

        updates = { service_plan: service_plan }
        updates['name'] = message.name if message.requested?(:name)
        updates['tags'] = message.tags if message.requested?(:tags)
        updates['dashboard_url'] = broker_response[:dashboard_url] if broker_response.key?(:dashboard_url)

        ServiceInstance.db.transaction do
          service_instance.save_with_new_operation(updates, broker_response[:last_operation])
          MetadataUpdate.update(service_instance, message)
          record_event(service_instance, message.audit_hash)
        end

        logger.info("Service instance update complete #{service_instance_guid}")
      end

      def job_name_in_configuration
        :service_instance_update
      end

      def max_attempts
        1
      end

      def resource_type
        'service_instances'
      end

      def resource_guid
        service_instance_guid
      end

      def display_name
        'service_instance.update'
      end

      private

      attr_reader :service_instance_guid, :message, :user_audit_info

      def service_instance
        ManagedServiceInstance.first(guid: service_instance_guid)
      end

      def service_plan
        plan = if message.service_plan_guid
                 ServicePlan.first(guid: message.service_plan_guid)
               else
                 service_instance.service_plan
               end

        service_plan_gone! unless plan
        plan
      end

      def previous_values
        {
          plan_id: service_instance.service_plan.broker_provided_id,
          service_id: service_instance.service.broker_provided_id,
          organization_id: service_instance.organization.guid,
          space_id: service_instance.space.guid,
        }
      end

      def record_event(service_instance, request_attrs)
        Repositories::ServiceEventRepository.new(@user_audit_info).
          record_service_instance_event(:update, service_instance, request_attrs)
      end

      def service_plan_gone!
        raise CloudController::Errors::ApiError.new_from_details('ServicePlanNotFound', service_instance_guid)
      end

      def gone!
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', service_instance_guid)
      end

      def aborted!
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'Update', 'delete in progress')
      end
    end
  end
end
