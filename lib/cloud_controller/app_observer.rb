require "cloud_controller/multi_response_message_bus_request"
require "models/runtime/droplet_uploader"
require "cloud_controller/diego_stager_task"

module VCAP::CloudController
  module AppObserver
    class << self
      extend Forwardable

      def configure(config, message_bus, dea_pool, stager_pool)
        @config = config
        @message_bus = message_bus
        @dea_pool = dea_pool
        @stager_pool = stager_pool
      end

      def deleted(app)
        AppStopper.new(@message_bus).stop(app)

        delete_package(app) if app.package_hash
        delete_buildpack_cache(app) if app.staged?
      end

      def updated(app)
        changes = app.previous_changes
        return unless changes

        if changes.has_key?(:state)
          react_to_state_change(app)
        elsif changes.has_key?(:instances)
          delta = changes[:instances][1] - changes[:instances][0]
          react_to_instances_change(app, delta)
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

      def stage_app(app, &completion_callback)
        if app.package_hash.nil? || app.package_hash.empty?
          raise Errors::ApiError.new_from_details("AppPackageInvalid", "The app package hash is empty")
        end

        if app.buildpack.custom? && !app.custom_buildpacks_enabled?
          raise Errors::ApiError.new_from_details("CustomBuildpacksDisabled")
        end


        if @config[:diego] && (app.environment_json || {})["CF_DIEGO_BETA"] == "true"
          task = DiegoStagerTask.new(@config[:staging][:timeout_in_seconds], @message_bus, app, dependency_locator.blobstore_url_generator)
        else
          task = AppStagerTask.new(@config, @message_bus, app, @dea_pool, @stager_pool, dependency_locator.blobstore_url_generator)
        end

        task.stage(&completion_callback)
      end

      def stage_if_needed(app, &success_callback)
        if app.needs_staging?
          app.last_stager_response = stage_app(app, &success_callback)
        else
          success_callback.call(:started_instances => 0)
        end
      end

      def react_to_state_change(app)
        if app.started?
          stage_if_needed(app) do |staging_result|
            started_instances = staging_result[:started_instances] || 0
            DeaClient.start(app, :instances_to_start => app.instances - started_instances)
            broadcast_app_updated(app)
          end
        else
          DeaClient.stop(app)
          broadcast_app_updated(app)
        end
      end

      def react_to_instances_change(app, delta)
        if app.started?
          DeaClient.change_running_instances(app, delta)
          broadcast_app_updated(app)
        end
      end

      def broadcast_app_updated(app)
        @message_bus.publish("droplet.updated", droplet: app.guid)
      end
    end
  end
end
