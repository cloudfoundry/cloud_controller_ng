require 'services/service_brokers/v2/errors/service_broker_bad_response'
require 'jobs/reoccurring_job'
require 'actions/v3/service_instance_delete'

module VCAP::CloudController
  module V3
    class DeleteServiceInstanceJob < VCAP::CloudController::Jobs::ReoccurringJob
      attr_reader :resource_guid

      def initialize(guid, user_audit_info)
        super()
        @resource_guid = guid
        @user_audit_info = user_audit_info
      end

      def perform
        return finish unless service_instance

        self.maximum_duration_seconds = service_instance.service_plan.try(:maximum_polling_duration)

        unless delete_in_progress?
          result = action.delete
          return finish if result[:finished]
        end

        result = action.poll
        return finish if result[:finished]

        self.polling_interval_seconds = result[:retry_after].to_i if result[:retry_after]
      rescue CloudController::Errors::ApiError => err
        raise err
      rescue => err
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', operation_type, err.message)
      end

      def handle_timeout
        action.update_last_operation_with_failure("Service Broker failed to #{operation} within the required time.")
      end

      def operation
        :deprovision
      end

      def operation_type
        'delete'
      end

      def resource_type
        'service_instance'
      end

      def display_name
        "#{resource_type}.#{operation_type}"
      end

      private

      attr_reader :user_audit_info

      def service_instance
        ManagedServiceInstance.first(guid: resource_guid)
      end

      def delete_in_progress?
        service_instance.last_operation&.type == 'delete' &&
          service_instance.last_operation&.state == 'in progress'
      end

      def action
        ServiceInstanceDelete.new(service_instance, Repositories::ServiceEventRepository.new(user_audit_info))
      end
    end
  end
end
