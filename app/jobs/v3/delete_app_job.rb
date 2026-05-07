require 'jobs/reoccurring_job'
require 'jobs/mixins/root_job_mixin'
require 'actions/app_delete'

module VCAP::CloudController
  module V3
    class DeleteAppJob < Jobs::ReoccurringJob
      include Jobs::RootJobMixin

      attr_reader :app_guid

      def initialize(app_guid, user_audit_info)
        super()
        @app_guid = app_guid
        @user_audit_info = user_audit_info
      end

      def perform
        activate_root_job_context

        app = AppModel.first(guid: app_guid)
        return finish unless app
        return if sub_jobs_pending?

        AppDelete.new(@user_audit_info).delete([app])
        finish
      rescue AppDelete::SubResourceError => e
        raise unless e.underlying_errors.all? { |err| err.is_a?(AppDelete::AsyncBindingDeletionsTriggered) }

        # All errors are async signals — binding jobs enqueued, wait for them
        nil
      rescue CloudController::Errors::ApiError
        raise
      rescue StandardError => e
        raise CloudController::Errors::ApiError.new_from_details('AppRecursiveDeleteFailed', app&.name || app_guid, e.message)
      ensure
        deactivate_root_job_context
      end

      def handle_timeout; end

      def resource_guid
        app_guid
      end

      def resource_type
        'app'
      end

      def display_name
        'app.delete'
      end

      def pollable_job_state
        PollableJobModel::PROCESSING_STATE
      end

      def max_attempts
        1
      end

      private

      attr_reader :user_audit_info
    end
  end
end
