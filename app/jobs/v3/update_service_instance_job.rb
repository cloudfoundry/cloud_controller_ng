# require 'messages/service_instance_update_managed_message'

module VCAP::CloudController
  module V3
    class UpdateServiceInstanceJob < VCAP::CloudController::Jobs::CCJob
      attr_reader :warnings

      def initialize(service_instance_guid, message:, user_audit_info:)
        super()
        @service_instance_guid = service_instance_guid
        @message = message
        @user_audit_info = user_audit_info
        @warnings = []
      end

      def perform
        logger = Steno.logger('cc.background')
        logger.info("Updating service instance #{service_instance_guid}")

        gone! if service_instance.nil?

        operation_in_progress = service_instance.last_operation.type
        aborted! if operation_in_progress != 'update'

        begin
          compatibility_checks

          client = VCAP::Services::ServiceClientProvider.provide({ instance: service_instance })

          maintenance_info = updated_maintenance_info(message, service_instance, service_plan)

          broker_response, err = client.update(
            service_instance,
            service_plan,
            accepts_incomplete: false,
            arbitrary_parameters: message.parameters || {},
            previous_values: previous_values,
            maintenance_info: maintenance_info,
            name: message.requested?(:name) ? message.name : service_instance.name,
          )
          raise err if err

          updates = message.updates.tap do |u|
            u[:service_plan_guid] = service_plan.guid
            u[:dashboard_url] = broker_response[:dashboard_url] if broker_response.key?(:dashboard_url)
            u[:maintenance_info] = maintenance_info if maintenance_info_updated?(message, service_instance, service_plan)
          end

          ServiceInstance.db.transaction do
            service_instance.save_with_new_operation(updates, broker_response[:last_operation])
            MetadataUpdate.update(service_instance, message)
            record_event(service_instance, message.audit_hash)
          end

          logger.info("Service instance update complete #{service_instance_guid}")
        rescue => err
          logger.info("Service instance update failed: #{err.message}")
          service_instance.save_with_new_operation({}, {
            state: 'failed',
            type: 'update',
            description: err.message
          })
          raise err
        end
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
          maintenance_info: service_instance.maintenance_info
        }
      end

      def maintenance_info_updated?(message, service_instance, updated_service_plan)
        plan_change_requested = updated_service_plan.guid != service_instance.service_plan.guid
        plan_change_requested || message.maintenance_info
      end

      def updated_maintenance_info(message, service_instance, updated_service_plan)
        plan_change_requested = updated_service_plan.guid != service_instance.service_plan.guid

        maintenance_info = if plan_change_requested
                             updated_service_plan.maintenance_info&.symbolize_keys
                           else
                             message.maintenance_info
                           end

        maintenance_info&.slice(:version)
      end

      def record_event(service_instance, request_attrs)
        Repositories::ServiceEventRepository.new(@user_audit_info).
          record_service_instance_event(:update, service_instance, request_attrs)
      end

      def compatibility_checks
        if service_instance.service_plan.service.volume_service? && volume_services_disabled?
          @warnings.push({ detail: ServiceInstance::VOLUME_SERVICE_WARNING })
        end

        if service_instance.service_plan.service.route_service? && route_services_disabled?
          @warnings.push({ detail: ServiceInstance::ROUTE_SERVICE_WARNING })
        end
      end

      def volume_services_disabled?
        !VCAP::CloudController::Config.config.get(:volume_services_enabled)
      end

      def route_services_disabled?
        !VCAP::CloudController::Config.config.get(:route_services_enabled)
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
