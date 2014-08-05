require "cloud_controller/multi_response_message_bus_request"
require "models/runtime/droplet_uploader"
require "cloud_controller/dea/app_stopper"
require "cloud_controller/backends"

module VCAP::CloudController
  module AppObserver
    class << self
      extend Forwardable

      def configure(backends)
        @backends = backends
      end

      def deleted(app)
        @backends.find_one_to_run(app).stop

        delete_package(app) if app.package_hash
        delete_buildpack_cache(app)
      end

      def updated(app)
        changes = app.previous_changes
        return unless changes

        if changes.has_key?(:state)
          react_to_state_change(app)
        elsif changes.has_key?(:instances)
          react_to_instances_change(app)
        end
      end

      private

      def delete_buildpack_cache(app)
        delete_job = Jobs::Runtime::BlobstoreDelete.new(app.guid, :buildpack_cache_blobstore)
        Jobs::Enqueuer.new(delete_job, queue: "cc-generic").enqueue()
      end

      def delete_package(app)
        delete_job = Jobs::Runtime::BlobstoreDelete.new(app.guid, :package_blobstore)
        Jobs::Enqueuer.new(delete_job, queue: "cc-generic").enqueue()
      end

      def validate_app_for_staging(app)
        if app.package_hash.nil? || app.package_hash.empty?
          raise Errors::ApiError.new_from_details("AppPackageInvalid", "The app package hash is empty")
        end

        if app.buildpack.custom? && !app.custom_buildpacks_enabled?
          raise Errors::ApiError.new_from_details("CustomBuildpacksDisabled")
        end
      end

      def react_to_state_change(app)
        staging_backend = @backends.find_one_to_stage(app)

        if !app.started?
          @backends.find_one_to_run(app).stop
        elsif staging_backend.needs_staging?
          validate_app_for_staging(app)

          staging_backend.stage
        else
          @backends.find_one_to_run(app).start
        end
      end

      def react_to_instances_change(app)
        @backends.find_one_to_run(app).scale if app.started?
      end
    end
  end
end
