require 'jobs/reoccurring_job'
require 'jobs/mixins/parent_job_mixin'
require 'jobs/v3/delete_binding_job'
require 'jobs/v3/delete_service_instance_job'
require 'actions/app_delete'
require 'actions/v3/service_instance_delete'
require 'actions/service_instance_unshare'

module VCAP::CloudController
  module V3
    class DeleteSpaceJob < Jobs::ReoccurringJob
      include Jobs::ParentJobMixin

      MAX_POLL_INTERVAL = 60
      MAX_CONCURRENT_CHILD_JOBS = 50

      attr_reader :space_guid, :warnings

      def initialize(space_guid, user_audit_info)
        super()
        @space_guid = space_guid
        @user_audit_info = user_audit_info
        @async_warning_shown = false
        @warnings = []
      end

      def perform
        @warnings = []
        clear_warnings

        space = Space.first(guid: space_guid)
        return finish unless space

        space.update(status: Space::DELETING) unless space.deleting?

        delete_apps(space)
        return if children_waiting? || space.app_models_dataset.any?

        delete_service_instances(space)
        return if children_waiting? || space.service_instances_dataset.where(is_gateway_service: true).any?

        cleanup_and_destroy(space)
        finish
      rescue CloudController::Errors::ApiError
        raise
      rescue StandardError => e
        raise CloudController::Errors::ApiError.new_from_details('SpaceDeletionFailed', space&.name || space_guid, e.message)
      end

      def handle_timeout; end

      def resource_guid
        space_guid
      end

      def resource_type
        'space'
      end

      def display_name
        'space.delete'
      end

      def pollable_job_state
        PollableJobModel::PROCESSING_STATE
      end

      def max_attempts
        1
      end

      private

      attr_reader :user_audit_info

      def next_execution_in
        configured = Config.config.get(:resource_deletion_poll_interval_seconds)
        return configured if configured

        [Config.config.get(:broker_client_default_async_poll_interval_seconds), MAX_POLL_INTERVAL].min
      end

      def delete_apps(space)
        app_deleter = AppDelete.new(@user_audit_info, parent_job_guid: my_pollable_job_guid)

        space.app_models_dataset.each do |app|
          break if child_job_limit_reached?

          app_deleter.delete([app])
        rescue AppDelete::AsyncBindingDeletionsTriggered
          show_async_warning
        end
      end

      def delete_service_instances(space)
        service_event_repository = Repositories::ServiceEventRepository.new(@user_audit_info)

        space.service_instances_dataset.where(is_gateway_service: true).each do |si|
          break if child_job_limit_reached?

          deleter = ServiceInstanceDelete.new(si, service_event_repository, parent_job_guid: my_pollable_job_guid)
          result = deleter.delete

          unless result[:finished]
            enqueue_child(DeleteServiceInstanceJob.new(si.guid, @user_audit_info))
            show_async_warning
          end
        rescue V3::ServiceInstanceDelete::UnbindingOperatationInProgress
          show_async_warning
        end
      end

      def cleanup_and_destroy(space)
        space.service_instances_dataset.where(is_gateway_service: false).each(&:destroy)

        unshare = ServiceInstanceUnshare.new
        space.service_instances_shared_from_other_spaces.each do |si|
          unshare.unshare(si, space, @user_audit_info)
        end

        service_event_repository = Repositories::ServiceEventRepository.new(@user_audit_info)
        space.service_brokers.each do |broker|
          has_instances = ServiceInstance.
                          join(:service_plans, id: :service_instances__service_plan_id).
                          join(:services, id: :service_plans__service_id).
                          where(services__service_broker_id: broker.id).
                          any?
          next if has_instances

          VCAP::Services::ServiceBrokers::ServiceBrokerRemover.new(service_event_repository).remove(broker)
        end

        Space.db.transaction do
          space.destroy
          Repositories::SpaceEventRepository.new.record_space_delete_request(space, @user_audit_info, true)
        end
      end

      def clear_warnings
        my_pollable_job&.warnings_dataset&.destroy
      end

      def child_job_limit_reached?
        parent = my_pollable_job
        return false unless parent

        parent.children_dataset.where(state: [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE]).count >= MAX_CONCURRENT_CHILD_JOBS
      end

      def show_async_warning
        return if @async_warning_shown

        # Maybe include the number of child jobs
        @warnings = [{ detail: 'Waiting for async operations to complete. Depending on the service broker, this could take several hours.' }]
        @async_warning_shown = true
      end
    end
  end
end
