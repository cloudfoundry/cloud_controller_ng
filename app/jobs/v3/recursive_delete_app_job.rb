require 'jobs/reoccurring_job'
require 'jobs/mixins/root_job_mixin'
require 'actions/app_delete'
require 'actions/app_stop'

module VCAP::CloudController
  module V3
    class RecursiveDeleteAppJob < Jobs::ReoccurringJob
      include Jobs::RootJobMixin

      attr_reader :app_guid

      def initialize(app_guid, user_audit_info)
        super()
        @app_guid = app_guid
        @user_audit_info = user_audit_info
      end

      def perform
        perform_with_root_job_handling do
          if sub_jobs_in_flight?
            logger.info("app delete #{app_guid} (job #{pollable_job_guid}) waiting on in-progress service binding deletions")
            return
          end

          log_failed_bindings
          raise_if_sub_jobs_failed

          app = AppModel.first(guid: app_guid)
          return finish unless app

          AppStop.stop(app: app, user_audit_info: @user_audit_info, delete_triggered: true) if app.desired_state != ProcessModel::STOPPED
          AppDelete.new(@user_audit_info).delete([app])
          finish
        end
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

      def max_attempts
        1
      end

      private

      attr_reader :user_audit_info

      def log_failed_bindings
        sub_resource_errors.each do |guid, error|
          logger.warn("app delete #{app_guid} (job #{pollable_job_guid}): service binding #{guid} deletion failed: #{error.message}")
        end
      end

      def in_progress_warning_detail
        'Deletion of the app is still in progress: one or more service bindings are still being deleted. ' \
          'It will complete once those operations finish.'
      end

      def sub_resource_errors
        app = AppModel.first(guid: app_guid)
        return [] unless app

        app.service_bindings.select(&:delete_failed?).map do |binding|
          [binding.guid, CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', binding.last_operation.description)]
        end
      end
    end
  end
end
