require 'jobs/reoccurring_job'
require 'jobs/mixins/recursive_delete_root_job_mixin'
require 'actions/v3/service_instance_delete'

module VCAP::CloudController
  module V3
    class RecursiveDeleteServiceInstanceJob < VCAP::CloudController::Jobs::ReoccurringJob
      include Jobs::RecursiveDeleteRootJobMixin

      attr_reader :resource_guid

      def initialize(resource_guid, user_audit_info)
        super()
        @resource_guid = resource_guid
        @user_audit_info = user_audit_info
      end

      def perform
        perform_with_root_job_handling do
          return finish unless service_instance

          self.maximum_duration_seconds = service_instance.service_plan.try(:maximum_polling_duration)

          unless delete_in_progress?
            result = action.delete
            return finish if result[:finished]
          end

          result = action.poll
          return finish if result[:finished]

          self.polling_interval_seconds = result[:retry_after].to_i if result[:retry_after]
        end
      ensure
        @service_instance = nil # drop the per-pass cache so it is not serialised into the reoccurring-job reschedule
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

      def in_progress_warning_detail
        'Deletion of the service instance is still in progress: one or more dependent resources are being ' \
          'deleted asynchronously. It will complete once those operations finish.'
      end

      def service_instance
        @service_instance ||= ManagedServiceInstance.first(guid: resource_guid)
      end

      def delete_in_progress?
        service_instance.last_operation&.type == 'delete' &&
          service_instance.last_operation&.state == 'in progress'
      end

      def action
        ServiceInstanceDelete.new(service_instance, Repositories::ServiceEventRepository.new(user_audit_info), fail_if_in_progress: false)
      end

      def sub_resource_errors
        si = service_instance
        return [] unless si

        failed_child_errors(si.service_bindings + si.service_keys + si.route_bindings)
      end
    end
  end
end
