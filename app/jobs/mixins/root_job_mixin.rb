require 'errors/sub_resource_error'
require 'cloud_controller/errors/api_error'
require 'cloud_controller/errors/compound_error'

module VCAP::CloudController
  module Jobs
    module RootJobMixin
      # Buffer added on top of the sub-jobs' next run_at so the root wakes just after them, never before.
      ROOT_JOB_BUFFER_SECONDS = 5

      private

      def perform_with_root_job_handling
        activate_root_job_context
        yield
      rescue SubResourceError => e
        return if e.any_in_progress?

        raise compound_error_for(e.failures)
      rescue CloudController::Errors::ApiError, CloudController::Errors::CompoundError
        raise
      rescue StandardError => e
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'delete', e.message)
      ensure
        deactivate_root_job_context
      end

      attr_reader :root_job, :sub_jobs

      # One shared tag for the whole recursive-delete subsystem so ops can grep it by a single logger name.
      # NOT memoized: this job YAML-serialises itself on reschedule, and a cached Steno::Logger would drag
      # its file-sink IO into the dump, reviving as an "uninitialized stream" that raises on the next write.
      def logger
        Steno.logger('cc.jobs.v3.recursive_delete')
      end

      # Resolves in any state (unlike root_job), so log lines stay searchable by this guid after the job settles.
      def pollable_job_guid
        @pollable_job_guid ||= PollableJobModel.first(resource_guid: resource_guid, operation: display_name)&.guid
      end

      def activate_root_job_context
        fetch_root_context
        Jobs::GenericEnqueuer.shared.activate_root_context(root_job_guid: root_job&.guid)
      end

      def deactivate_root_job_context
        # Must clear in perform's ensure: the job YAML-serialises itself on reschedule, reviving a stale cache otherwise.
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
        job = PollableJobModel.find_active_delete(resource_guid: resource_guid, operation: display_name)
        return nil unless job

        active_guids = job.sub_jobs_dataset.where(state: [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE]).select_map(:delayed_job_guid)
        return nil if active_guids.empty?

        latest = Delayed::Job.where(guid: active_guids).max(:run_at)
        now = Delayed::Job.db_time_now
        return nil unless latest && latest > now

        (latest - now).ceil
      end

      def sub_jobs_in_flight?
        return false if active_sub_jobs.empty?

        add_in_progress_warning(root_job)
        true
      end

      def raise_if_sub_jobs_failed
        return if sub_job_errors.empty?

        raise CloudController::Errors::CompoundError.new(all_failure_errors)
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

      def compound_error_for(raised_failures)
        errors = all_failure_errors
        errors = raised_failures.map { |e| CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', e.message) } if errors.empty?
        CloudController::Errors::CompoundError.new(errors)
      end

      def all_failure_errors
        by_guid = {}
        sub_resource_errors.each { |guid, err| by_guid[guid] = err }
        sub_job_errors.each { |guid, err| by_guid[guid] ||= err }
        by_guid.values
      end

      def sub_job_errors
        sub_jobs.select { |s| s.state == PollableJobModel::FAILED_STATE }.map do |sub_job|
          [sub_job.resource_guid, CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', sub_job_error_detail(sub_job))]
        end
      end

      def sub_resource_errors
        []
      end

      def sub_job_error_detail(sub_job)
        fallback = "#{sub_job.resource_type} #{sub_job.resource_guid}"
        return fallback if sub_job.cf_api_error.nil?

        parsed = Psych.safe_load(sub_job.cf_api_error, strict_integer: true)
        detail = parsed && parsed['errors']&.first&.fetch('detail', nil)
        detail.presence || fallback
      rescue Psych::Exception
        fallback
      end
    end
  end
end
