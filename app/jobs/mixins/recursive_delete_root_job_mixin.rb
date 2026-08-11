require 'errors/sub_resource_error'
require 'cloud_controller/errors/api_error'
require 'cloud_controller/errors/compound_error'
require 'jobs/v3/sub_resource_failures'

module VCAP::CloudController
  module Jobs
    module RecursiveDeleteRootJobMixin
      # Buffer added on top of the sub-jobs' next run_at so the root wakes just after them, never before.
      ROOT_JOB_BUFFER_SECONDS = 5

      # Reuses the fetched context when active (the common path); fetch from db as fallback
      def root_job_guid
        @root_job&.guid || PollableJobModel.first(resource_guid: resource_guid, operation: display_name)&.guid
      end

      # Override default start_time to use the time when sub-jobs completed
      def start_time
        @sub_jobs_completed_at || super
      end

      private

      # While sub-jobs are still deleting, never time out: the wait is legitimate and each sub-job has its own timeout
      # Once they finish, restart the remaining duration from that point so it bounds the root's own delete
      def next_enqueue_would_exceed_maximum_duration?
        return false if active_sub_jobs_in_db?

        @sub_jobs_completed_at ||= Time.now
        super
      end

      def perform_with_root_job_handling
        activate_root_job_context

        if sub_jobs_in_flight?
          add_in_progress_warning(root_job)
          logger.info("#{display_name} #{resource_guid} (job #{root_job_guid}) waiting on in-progress sub-resource deletions")
          return
        end

        raise_if_sub_jobs_failed

        yield
      rescue SubResourceError => e
        failures = sub_resource_failures
        if e.any_in_progress?
          failures.log_immediate(e.failures) # async still polling: defer; the surfaced sync failures are retried next run
          return
        end

        raise failures.log_and_return(failures.compound_error(e.failures)) # sync failure, nothing async pending
      rescue CloudController::Errors::CompoundError => e
        raise sub_resource_failures.log_and_return(e) # an async sub-job failed terminally
      rescue CloudController::Errors::ApiError
        raise
      rescue StandardError => e
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'delete', e.message)
      ensure
        deactivate_root_job_context
      end

      attr_reader :root_job, :sub_jobs

      def logger
        Steno.logger('cc.jobs.v3.recursive_delete')
      end

      def activate_root_job_context
        fetch_root_context
        Jobs::GenericEnqueuer.shared.activate_root_context(root_job_guid: root_job&.guid)
      end

      def deactivate_root_job_context
        @root_job = nil
        @sub_jobs = nil
        Jobs::GenericEnqueuer.shared.deactivate_root_context
      end

      def fetch_root_context
        @root_job = PollableJobModel.find_active_delete(resource_guid: resource_guid, operation: display_name)
        @sub_jobs = @root_job ? @root_job.sub_jobs : []
      end

      def active_sub_jobs
        sub_jobs.select { |s| [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE].include?(s.state) }
      end

      # Pace off the slowest active sub-job's next run (else the normal interval) so the root never re-runs early.
      def next_execution_in
        interval = (seconds_until_slowest_sub_job || super) + ROOT_JOB_BUFFER_SECONDS
        [interval, Config.config.get(:broker_client_max_async_poll_interval_seconds)].min
      end

      def seconds_until_slowest_sub_job
        active_guids = active_sub_jobs_dataset&.select_map(:delayed_job_guid) || []
        return nil if active_guids.empty?

        latest = Delayed::Job.where(guid: active_guids).max(:run_at)
        now = Delayed::Job.db_time_now
        return nil unless latest && latest > now

        (latest - now).ceil
      end

      def active_sub_jobs_in_db?
        active_sub_jobs_dataset&.any? || false
      end

      # Non-terminal sub-jobs of this root read fresh from the DB - used after the cached context has been cleared
      def active_sub_jobs_dataset
        job = PollableJobModel.find_active_delete(resource_guid: resource_guid, operation: display_name)
        return unless job

        job.sub_jobs_dataset.where(state: [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE])
      end

      def sub_jobs_in_flight?
        active_sub_jobs.any?
      end

      def raise_if_sub_jobs_failed
        return unless sub_jobs.any? { |s| s.state == PollableJobModel::FAILED_STATE }

        raise sub_resource_failures.compound_error
      end

      # Rebuilt per call, never memoised: the job YAML-serialises itself on reschedule.
      def sub_resource_failures
        VCAP::CloudController::V3::SubResourceFailures.new(
          sub_jobs: sub_jobs, sub_resource_errors: sub_resource_errors, logger: logger,
          display_name: display_name, resource_guid: resource_guid, root_job_guid: root_job_guid
        )
      end

      def add_in_progress_warning(job)
        return if job.warnings_dataset.any?

        JobWarningModel.create(job: job, detail: in_progress_warning_detail)
      rescue Sequel::Error => e
        logger.warn("could not add in-progress warning for #{resource_type} #{resource_guid} (job #{job.guid}): #{e.message}")
      end

      def in_progress_warning_detail
        'This operation is still in progress: it is waiting for one or more dependent operations to finish.'
      end

      # Host hook: [guid, ApiError] pairs for child resources that failed synchronously with no async sub-job.
      def sub_resource_errors
        []
      end

      # Maps failed child resources to the [guid, ApiError] pairs sub_resource_errors returns.
      def failed_child_errors(children)
        children.select(&:delete_failed?).map do |child|
          identity = "#{child.class.name.demodulize.underscore} #{child.guid}"
          [child.guid, CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', "#{identity}: #{child.last_operation.description}")]
        end
      end
    end
  end
end
