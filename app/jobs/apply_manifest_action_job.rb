module VCAP::CloudController
  module Jobs
    class ApplyManifestActionJob < VCAP::CloudController::Jobs::CCJob
      def initialize(app_guid, apply_manifest_message, apply_manifest_action)
        @app_guid = app_guid
        @apply_manifest_message = apply_manifest_message
        @apply_manifest_action  = apply_manifest_action
      end

      def perform
        logger = Steno.logger('cc.background')
        logger.info("Applying app manifest to app: #{resource_guid}")

        apply_manifest_action.apply(resource_guid, apply_manifest_message)
      rescue AppPatchEnvironmentVariables::InvalidApp,
             AppUpdate::InvalidApp,
             ProcessScale::InvalidProcess,
             ProcessUpdate::InvalidProcess => e

        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', e.message)
      end

      def job_name_in_configuration
        :apply_manifest_job
      end

      def max_attempts
        1
      end

      def resource_type
        'app'
      end

      def display_name
        'app.apply_manifest'
      end

      def resource_guid
        @app_guid
      end

      private

      attr_reader :apply_manifest_action, :apply_manifest_message
    end
  end
end
