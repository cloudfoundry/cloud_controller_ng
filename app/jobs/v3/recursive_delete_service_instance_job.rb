require 'jobs/reoccurring_job'
require 'jobs/mixins/root_job_mixin'
require 'actions/v3/service_instance_delete'

module VCAP::CloudController
  module V3
    class RecursiveDeleteServiceInstanceJob < VCAP::CloudController::Jobs::ReoccurringJob
      include Jobs::RootJobMixin

      attr_reader :resource_guid

      def initialize(guid, user_audit_info)
        super()
        @resource_guid = guid
        @user_audit_info = user_audit_info
      end

      def perform
        perform_with_root_job_handling do
          if sub_jobs_in_flight?
            logger.info("service instance delete #{resource_guid} (job #{root_job_guid}) waiting on in-progress binding deletions")
            return
          end

          log_failed_children
          raise_if_sub_jobs_failed

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
        'Deletion of the service instance is still in progress: one or more bindings are still being ' \
          'deleted. It will complete once those operations finish.'
      end

      def service_instance
        ManagedServiceInstance.first(guid: resource_guid)
      end

      def on_recursive_delete_failure(error)
        return unless service_instance
        return if service_instance.last_operation&.state == 'failed'

        action.update_last_operation_with_failure(error.underlying_errors.map(&:message).join("\n"))
      end

      def on_recursive_delete_in_progress
        return unless service_instance
        return if delete_marked?

        action.update_last_operation_in_progress('Waiting for bindings of the service instance to be deleted.')
      end

      def delete_in_progress?
        service_instance.last_operation&.type == 'delete' &&
          service_instance.last_operation&.state == 'in progress' &&
          service_instance.last_operation&.broker_provided_operation.present?
      end

      def delete_marked?
        service_instance.last_operation&.type == 'delete' &&
          ['in progress', 'failed'].include?(service_instance.last_operation&.state)
      end

      def action
        ServiceInstanceDelete.new(service_instance, Repositories::ServiceEventRepository.new(user_audit_info), fail_if_in_progress: false)
      end

      def log_failed_children
        sub_resource_errors.each do |guid, error|
          logger.warn("service instance delete #{resource_guid} (job #{root_job_guid}): binding #{guid} deletion failed: #{error.message}")
        end
      end

      def sub_resource_errors
        si = service_instance
        return [] unless si

        children = si.service_bindings + si.service_keys + RouteBinding.where(service_instance: si).all
        children.select(&:delete_failed?).map do |child|
          identity = "#{child.class.name.demodulize.underscore} #{child.guid}"
          [child.guid, CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', "#{identity}: #{child.last_operation.description}")]
        end
      end
    end
  end
end
