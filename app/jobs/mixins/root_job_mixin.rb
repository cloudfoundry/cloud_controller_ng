module VCAP::CloudController
  module Jobs
    module RootJobMixin
      private

      def root_job
        PollableJobModel.find(
          resource_guid: resource_guid,
          operation: display_name,
          state: [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE]
        )
      end

      def activate_root_job_context
        job = root_job
        sub_jobs = job ? job.sub_jobs_dataset.select(:state, :delayed_job_guid).all : []

        active_states = [PollableJobModel::PROCESSING_STATE, PollableJobModel::POLLING_STATE]
        @active_sub_job_guids = sub_jobs.select { |j| active_states.include?(j.state) }.map(&:delayed_job_guid)
        failed_count = sub_jobs.count { |j| j.state == PollableJobModel::FAILED_STATE }

        Jobs::GenericEnqueuer.shared.activate_root_context(
          root_job_guid: job&.guid,
          active_sub_job_guids: @active_sub_job_guids,
          sub_jobs_failed: failed_count
        )
      end

      def deactivate_root_job_context
        @active_sub_job_guids = Jobs::GenericEnqueuer.shared.active_sub_job_guids.dup
        Jobs::GenericEnqueuer.shared.deactivate_root_context
      end

      def active_sub_job_guids
        @active_sub_job_guids || []
      end

      def sub_jobs_pending?
        enqueuer = Jobs::GenericEnqueuer.shared
        return false if enqueuer.sub_jobs_active.zero? && enqueuer.sub_jobs_failed.zero?

        if enqueuer.sub_jobs_active.positive?
          warn_about_failed_sub_jobs if enqueuer.sub_jobs_failed.positive?
          return true
        end

        raise_sub_job_failure if enqueuer.sub_jobs_failed.positive?
        false
      end

      def warn_about_failed_sub_jobs
        @warnings ||= []
        @warnings << { detail: 'One or more sub-jobs have failed. Waiting for remaining operations to complete before reporting.' }
      end

      def raise_sub_job_failure
        job = root_job
        failed_jobs = job.sub_jobs_dataset.where(state: PollableJobModel::FAILED_STATE).all
        details = failed_jobs.map { |j| "#{j.operation} #{j.resource_guid}" }.join(', ')
        raise CloudController::Errors::ApiError.new_from_details(
          'SpaceDeletionFailed', resource_guid, "Sub-job(s) failed: #{details}"
        )
      end
    end
  end
end
