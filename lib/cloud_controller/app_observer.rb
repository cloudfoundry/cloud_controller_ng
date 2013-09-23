require "vcap/stager/client"
require "cloud_controller/multi_response_message_bus_request"
require "models/runtime/droplet"

module VCAP::CloudController
  module AppObserver
    class << self
      extend Forwardable

      def configure(config, message_bus, stager_pool)
        @config = config
        @message_bus = message_bus
        @stager_pool = stager_pool
      end

      def deleted(app)
        DeaClient.stop(app)

        if app.package_hash
          delete_package(app)
        end

        if app.staged?
          CloudController::Droplet.new(app, droplet_blobstore).delete
          delete_buildpack_cache(app)
        end
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
        buildpack_cache_blobstore.delete(app.guid)
      end

      def delete_package(app)
        package_blobstore.delete(app.guid)
      end

      def_delegators :dependency_locator, :buildpack_cache_blobstore,
                     :package_blobstore, :droplet_blobstore

      def dependency_locator
        CloudController::DependencyLocator.instance
      end

      def stage_app(app, &completion_callback)
        if app.package_hash.nil? || app.package_hash.empty?
          raise Errors::AppPackageInvalid, "The app package hash is empty"
        end

        task = AppStagerTask.new(@config, @message_bus, app, @stager_pool, dependency_locator.blobstore_url_generator)
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
          stage_if_needed(app) do |staging_result|
            DeaClient.change_running_instances(app, delta)
            broadcast_app_updated(app)
          end
        end
      end

      def broadcast_app_updated(app)
        @message_bus.publish("droplet.updated", droplet: app.guid)
      end
    end
  end
end
