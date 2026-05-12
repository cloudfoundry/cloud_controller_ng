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

        space.mark_deleting! if retry_number.zero?

        delete_apps(space)
        return set_async_warning if apps_pending?(space)

        delete_service_instances(space)
        return set_async_warning if service_instances_pending?(space)

        cleanup_and_destroy(space)
        finish
      rescue CloudController::Errors::ApiError
        reset_space_status
        raise
      rescue StandardError => e
        reset_space_status
        raise CloudController::Errors::ApiError.new_from_details('SpaceDeletionFailed', space&.name || space_guid,
                                                                 "#{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
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

      # Buffer added on top of the sub-jobs' next scheduled run_at so the root job
      # always wakes up after its sub-jobs have had a chance to poll the broker.
      # If a broker returns Retry-After: 600, the sub-job's run_at will be now+600s,
      # and the root job will sleep 605s — not wasting cycles polling before that.
      # Capped at broker_client_max_async_poll_interval_seconds — if an operator
      # configured a maximum wait between async checks, the root job respects that.
      ROOT_JOB_BUFFER_SECONDS = 5

      private

      attr_reader :user_audit_info

      def next_execution_in
        max_interval = Config.config.get(:broker_client_max_async_poll_interval_seconds)
        guids = fresh_sub_job_delayed_job_guids
        if guids.any?
          latest = Delayed::Job.where(guid: guids).max(:run_at)
          return [(latest - Time.now).ceil + ROOT_JOB_BUFFER_SECONDS, max_interval].min if latest && latest > Time.now
        end
        [super + ROOT_JOB_BUFFER_SECONDS, max_interval].min
      end

      # Re-read delayed_job_guids from DB because sub-jobs get new delayed_job rows
      # each time they re-enqueue (ReoccurringJob creates a new Delayed::Job per cycle).
      def fresh_sub_job_delayed_job_guids
        job = root_job
        return [] unless job

        active_states = [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE]
        job.sub_jobs_dataset.where(state: active_states).select_map(:delayed_job_guid)
      end

      def delete_apps(space)
        app_deleter = AppDelete.new(@user_audit_info)

        space.app_models_dataset.each do |app|
          break if Jobs::GenericEnqueuer.shared.sub_job_count >= MAX_SUB_JOBS

          app_deleter.delete([app])
        rescue Sequel::NoExistingObject
          nil
        rescue AppDelete::SubResourceError => e
          raise unless e.underlying_errors.all? { |err| async_binding_error?(err) }
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
        rescue CloudController::Errors::ApiError => e
          raise unless e.name == 'AsyncServiceInstanceOperationInProgress'
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
        return unless retry_number.zero?

        @warnings = [{ detail: 'Deletion in progress. Waiting for operations on service instances and bindings to complete.' }]
      end

      def reset_space_status
        space = Space.first(guid: space_guid)
        space&.update(status: nil)
      end

      def apps_pending?(space)
        sub_jobs_pending? || space.app_models_dataset.any?
      end

      def service_instances_pending?(space)
        sub_jobs_pending? || space.service_instances_dataset.where(is_gateway_service: true).any?
      end

      def async_binding_error?(err)
        err.is_a?(AppDelete::AsyncBindingDeletionsTriggered) ||
          (err.is_a?(CloudController::Errors::ApiError) && err.name == 'AsyncServiceInstanceOperationInProgress')
      end
    end
  end
end
