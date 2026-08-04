require 'errors/sub_resource_error'
require 'cloud_controller/errors/api_error'
require 'cloud_controller/errors/compound_error'

module VCAP::CloudController
  module Jobs
    module RecursiveDeleteRootJobMixin
      # Buffer added on top of the sub-jobs' next run_at so the root wakes just after them, never before.
      ROOT_JOB_BUFFER_SECONDS = 5

      def root_job_guid
        @root_job_guid ||= PollableJobModel.first(resource_guid: resource_guid, operation: display_name)&.guid
      end

      private

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
        if e.any_in_progress?
          log_immediate_failures(e.failures) # log failures that surfaced this run; async ones still polling defer us and are retried on the next run
          return
        end

        raise log_recursive_delete_failure(compound_error_for(e.failures)) # sync error occurred & no async job pending -> log and fail
      rescue CloudController::Errors::CompoundError => e
        raise log_recursive_delete_failure(e) # async sub job failed -> log and fail
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
        active_sub_jobs.any?
      end

      def raise_if_sub_jobs_failed
        return unless sub_jobs.any? { |s| s.state == PollableJobModel::FAILED_STATE }

        raise CloudController::Errors::CompoundError.new(all_failure_errors)
      end

      # Logs failures that surfaced during this run (a binding's unbind failed immediately rather than going
      # async-in-progress). Makes them visible to operators even though the run defers on the async ones,
      # which are retried on the next run.
      def log_immediate_failures(failures)
        failures.each do |error|
          logger.warn("#{display_name} #{resource_guid} (job #{root_job_guid}) sub-resource deletion failed: #{error.message}")
        end
      end

      # Logs each underlying failure and returns the error so callers can `raise log_recursive_delete_failure(error)`.
      def log_recursive_delete_failure(error)
        error.underlying_errors.each do |underlying|
          logger.warn("#{display_name} #{resource_guid} (job #{root_job_guid}) sub-resource deletion failed: #{underlying.message}")
        end
        error
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
        identity = "#{sub_job.resource_type} #{sub_job.resource_guid}"
        return identity if sub_job.cf_api_error.nil?

        parsed = Psych.safe_load(sub_job.cf_api_error, strict_integer: true)
        detail = parsed && parsed['errors']&.first&.fetch('detail', nil)
        detail.present? ? "#{identity}: #{detail}" : identity
      rescue Psych::Exception
        identity
      end
    end
  end
end
