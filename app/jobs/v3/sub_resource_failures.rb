require 'cloud_controller/errors/api_error'
require 'cloud_controller/errors/compound_error'

module VCAP::CloudController
  module V3
    # Merges failed sub-jobs (async child rows) and failed sub-resources (sync unbinds, no sub-job row) into one error.
    # Never memoised onto the job: the job YAML-serialises itself on reschedule.
    class SubResourceFailures
      # sub_resource_errors: [guid, ApiError] pairs from the host job's sync-failure hook (empty for jobs with none).
      def initialize(sub_jobs:, sub_resource_errors:, logger:, display_name:, resource_guid:, root_job_guid:)
        @sub_jobs = sub_jobs
        @sub_resource_errors = sub_resource_errors
        @logger = logger
        @display_name = display_name
        @resource_guid = resource_guid
        @root_job_guid = root_job_guid
      end

      # Falls back to the raised sync failures when nothing durable was recorded.
      def compound_error(raised_failures=[])
        errors = merged_errors
        errors = raised_failures.map { |e| CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', e.message) } if errors.empty?
        CloudController::Errors::CompoundError.new(errors)
      end

      # Surfaces failures that failed immediately this run, so they are visible even though we defer on the async ones.
      def log_immediate(failures)
        failures.each { |error| log_failure(error.message) }
      end

      def log_and_return(error)
        error.underlying_errors.each { |underlying| log_failure(underlying.message) }
        error
      end

      private

      def log_failure(message)
        @logger.warn("#{@display_name} #{@resource_guid} (job #{@root_job_guid}) sub-resource deletion failed: #{message}")
      end

      def merged_errors
        by_guid = {}
        @sub_resource_errors.each { |guid, err| by_guid[guid] = err }
        sub_job_errors.each { |guid, err| by_guid[guid] ||= err }
        by_guid.values
      end

      def sub_job_errors
        @sub_jobs.select { |s| s.state == PollableJobModel::FAILED_STATE }.map do |sub_job|
          [sub_job.resource_guid, CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', sub_job_error_detail(sub_job))]
        end
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
