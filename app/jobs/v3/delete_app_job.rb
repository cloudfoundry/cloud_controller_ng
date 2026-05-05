require 'jobs/reoccurring_job'
require 'jobs/mixins/parent_job_mixin'
require 'actions/app_delete'

module VCAP::CloudController
  module V3
    class DeleteAppJob < Jobs::ReoccurringJob
      include Jobs::ParentJobMixin

      attr_reader :app_guid

      def initialize(app_guid, user_audit_info)
        super()
        @app_guid = app_guid
        @user_audit_info = user_audit_info
      end

      def perform
        app = AppModel.first(guid: app_guid)
        return finish unless app
        return if children_waiting?

        AppDelete.new(@user_audit_info, parent_job_guid: my_pollable_job_guid).delete([app])
        finish
      rescue AppDelete::AsyncBindingDeletionsTriggered
        # Binding jobs already enqueued by BindingsDeleteMixin with parent_guid set — wait for them
        nil
      rescue CloudController::Errors::ApiError
        raise
      rescue StandardError => e
        raise CloudController::Errors::ApiError.new_from_details('AppRecursiveDeleteFailed', app&.name || app_guid, e.message)
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
