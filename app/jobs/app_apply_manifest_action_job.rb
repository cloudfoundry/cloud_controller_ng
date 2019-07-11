module VCAP::CloudController
  module Jobs
    class AppApplyManifestActionJob < VCAP::CloudController::Jobs::CCJob
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
             AppApplyManifest::NoDefaultDomain,
             ProcessScale::InvalidProcess,
             ProcessScale::SidecarMemoryLessThanProcessMemory,
             ProcessUpdate::InvalidProcess,
             SidecarCreate::InvalidSidecar,
             SidecarUpdate::InvalidSidecar,
             ManifestRouteUpdate::InvalidRoute,
             Route::InvalidOrganizationRelation,
             RouteMappingCreate::SpaceMismatch,
             ServiceBindingCreate::InvalidServiceBinding => e

        error = CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', e.message)
        error.set_backtrace(e.backtrace)
        raise error
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
