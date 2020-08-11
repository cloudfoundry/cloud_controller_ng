require 'jobs/v3/service_instance_async_job'

module VCAP::CloudController
  module V3
    class UpdateServiceInstanceJob < ServiceInstanceAsyncJob
      def initialize(
        service_instance_guid,
        user_audit_info:,
        message:,
        request_attr: {}
      )
        super(service_instance_guid, user_audit_info)
        @message = message
        @update_response = {}
        @request_attr = request_attr
      end

      def operation
        :update
      end

      def operation_type
        'update'
      end

      def send_broker_request(client)
        @update_response, err = client.update(
          service_instance,
          service_plan,
          accepts_incomplete: true,
          arbitrary_parameters: message.parameters || {},
          previous_values: previous_values,
          maintenance_info: maintenance_info,
          name: message.requested?(:name) ? message.name : service_instance.name,
        )
        raise err if err

        @update_response
      end

      def operation_succeeded
        updates = message.updates.tap do |u|
          u[:service_plan_guid] = service_plan.guid
          u[:dashboard_url] = @update_response[:dashboard_url] if @update_response.key?(:dashboard_url)
          u[:maintenance_info] = maintenance_info if maintenance_info_updated?
        end

        ServiceInstance.db.transaction do
          service_instance.update_service_instance(updates)
          MetadataUpdate.update(service_instance, message)
        end
      end

      private

      attr_reader :message

      def service_plan_gone!
        raise CloudController::Errors::ApiError.new_from_details('ServicePlanNotFound', service_instance_guid)
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
          maintenance_info: service_instance.maintenance_info
        }
      end

      def maintenance_info_updated?
        plan_change_requested = service_plan.guid != service_instance.service_plan.guid
        plan_change_requested || message.maintenance_info
      end

      def maintenance_info
        plan_change_requested = service_plan.guid != service_instance.service_plan.guid

        info = if plan_change_requested
                 service_plan.maintenance_info&.symbolize_keys
               else
                 message.maintenance_info
               end

        info&.slice(:version)
      end
    end
  end
end
