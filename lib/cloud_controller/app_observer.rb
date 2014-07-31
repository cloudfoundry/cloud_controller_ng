require "cloud_controller/multi_response_message_bus_request"
require "models/runtime/droplet_uploader"
require "cloud_controller/dea/app_stopper"
require "cloud_controller/backends"

module VCAP::CloudController
  module AppObserver
    class << self
      extend Forwardable

      def configure(config, message_bus, dea_pool, stager_pool, diego_client)
        @config = config
        @message_bus = message_bus
        @dea_pool = dea_pool
        @stager_pool = stager_pool
        @diego_client = diego_client
        @backends = Backends.new(@message_bus, @diego_client)
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

      def run
        @stager_pool.register_subscriptions
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

      def dependency_locator
        CloudController::DependencyLocator.instance
      end

      def validate_app_for_staging(app)
        if app.package_hash.nil? || app.package_hash.empty?
          raise Errors::ApiError.new_from_details("AppPackageInvalid", "The app package hash is empty")
        end

        if app.buildpack.custom? && !app.custom_buildpacks_enabled?
          raise Errors::ApiError.new_from_details("CustomBuildpacksDisabled")
        end
      end

      def stage_app_on_diego(app)
        validate_app_for_staging(app)
        @diego_client.send_stage_request(app, VCAP.secure_uuid)
      end

      def react_to_state_change(app)
        if !app.started?
          @backends.find_one_to_run(app).stop
        elsif app.needs_staging?
          if @diego_client.staging_needed(app)
            stage_app_on_diego(app)
          else
            validate_app_for_staging(app)
            task = Dea::AppStagerTask.new(@config, @message_bus, app, @dea_pool, @stager_pool, dependency_locator.blobstore_url_generator)
            app.last_stager_response = task.stage do |staging_result|
              @backends.find_one_to_run(app).start(staging_result)
            end
          end
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
