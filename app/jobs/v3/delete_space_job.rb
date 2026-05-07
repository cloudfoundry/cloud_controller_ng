require 'jobs/reoccurring_job'
require 'jobs/mixins/root_job_mixin'
require 'jobs/v3/delete_binding_job'
require 'jobs/v3/delete_service_instance_job'
require 'actions/app_delete'
require 'actions/v3/service_instance_delete'
require 'actions/service_instance_unshare'

module VCAP::CloudController
  module V3
    class DeleteSpaceJob < Jobs::ReoccurringJob
      include Jobs::RootJobMixin

      MAX_POLL_INTERVAL = 60
      MAX_SUB_JOBS = 50

      attr_reader :space_guid, :warnings

      def initialize(space_guid, user_audit_info)
        super()
        @space_guid = space_guid
        @user_audit_info = user_audit_info
        @warnings = []
      end

      def perform
        @warnings = []
        activate_root_job_context

        space = Space.first(guid: space_guid)
        return finish unless space

        space.update(status: Space::DELETING) unless space.deleting?

        delete_apps(space)
        return set_async_warning if sub_jobs_pending? || space.app_models_dataset.any?

        delete_service_instances(space)
        return set_async_warning if sub_jobs_pending? || space.service_instances_dataset.where(is_gateway_service: true).any?

        cleanup_and_destroy(space)
        finish
      rescue CloudController::Errors::ApiError
        reset_space_status
        raise
      rescue StandardError => e
        reset_space_status
        raise CloudController::Errors::ApiError.new_from_details('SpaceDeletionFailed', space&.name || space_guid, e.message)
      ensure
        deactivate_root_job_context
      end

      def handle_timeout
        reset_space_status
      end

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
        app_deleter = AppDelete.new(@user_audit_info)

        space.app_models_dataset.each do |app|
          break if Jobs::GenericEnqueuer.shared.sub_job_count >= MAX_SUB_JOBS

          app_deleter.delete([app])
        rescue Sequel::NoExistingObject
          nil
        rescue AppDelete::SubResourceError => e
          raise unless e.underlying_errors.all? { |err| err.is_a?(AppDelete::AsyncBindingDeletionsTriggered) }
        end
      end

      def delete_service_instances(space)
        service_event_repository = Repositories::ServiceEventRepository.new(@user_audit_info)

        space.service_instances_dataset.where(is_gateway_service: true).each do |si|
          break if Jobs::GenericEnqueuer.shared.sub_job_count >= MAX_SUB_JOBS

          deleter = ServiceInstanceDelete.new(si, service_event_repository)
          result = deleter.delete

          Jobs::GenericEnqueuer.shared.enqueue_pollable(DeleteServiceInstanceJob.new(si.guid, @user_audit_info)) unless result[:finished]
        rescue Sequel::NoExistingObject, V3::ServiceInstanceDelete::UnbindingOperatationInProgress
          nil
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

      def set_async_warning
        @warnings = [{ detail: 'Waiting for async service operations to complete. Depending on the service broker, this could take several hours.' }]
      end

      def reset_space_status
        space = Space.first(guid: space_guid)
        space&.update(status: nil)
      end
    end
  end
end
