module VCAP::CloudController
  module Jobs
    class SpaceApplyManifestActionJob < VCAP::CloudController::Jobs::CCJob
      def initialize(space, app_guid_message_hash, apply_manifest_action, user_audit_info)
        @space = space
        @app_guid_message_hash = app_guid_message_hash
        @apply_manifest_action = apply_manifest_action
        @user_audit_info = user_audit_info
      end

      def perform
        logger = Steno.logger('cc.background')
        logger.info("Applying app manifest to app: #{resource_guid}")

        app_guid_message_hash.each do |app_guid, message|
          apply_manifest_action.apply(app_guid, message)
        rescue AppPatchEnvironmentVariables::InvalidApp,
               AppUpdate::InvalidApp,
               AppApplyManifest::NoDefaultDomain,
               ProcessCreate::InvalidProcess,
               ProcessScale::InvalidProcess,
               ProcessUpdate::InvalidProcess,
               ManifestRouteUpdate::InvalidRoute,
               Route::InvalidOrganizationRelation,
               AppApplyManifest::Error,
               AppApplyManifest::ServiceBindingError,
               SidecarCreate::InvalidSidecar,
               SidecarUpdate::InvalidSidecar,
               ProcessScale::SidecarMemoryLessThanProcessMemory => e

          app_name = AppModel.find(guid: app_guid)&.name
          error_message = app_name ? "For application '#{app_name}': #{e.message}" : e.message
          raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', error_message)
        rescue CloudController::Errors::NotFound,
               StructuredError => e

          app_name = AppModel.find(guid: app_guid)&.name
          e.error_prefix = "For application '#{app_name}': " if app_name
          raise e
        end
      end

      def job_name_in_configuration
        :apply_space_manifest_job
      end

      def max_attempts
        1
      end

      def resource_type
        'space'
      end

      def display_name
        'space.apply_manifest'
      end

      def resource_guid
        space.guid
      end

      private

      attr_reader :space, :apply_manifest_action, :app_guid_message_hash, :user_audit_info
    end
  end
end
