require 'cloud_controller/multi_response_message_bus_request'
require 'models/runtime/droplet_uploader'
require 'cloud_controller/dea/app_stopper'

module VCAP::CloudController
  module AppObserver
    class << self
      extend Forwardable

      def configure(stagers, runners)
        @stagers = stagers
        @runners = runners
      end

      def deleted(app)
        @runners.runner_for_app(app).stop

        delete_package(app) if app.package_hash
        delete_buildpack_cache(app)
      end

      def updated(app)
        changes = app.previous_changes
        return unless changes

        if changes.key?(:state) || changes.key?(:diego) || changes.key?(:enable_ssh)
          react_to_state_change(app)
        elsif changes.key?(:instances)
          react_to_instances_change(app)
        end
      end

      def routes_changed(app)
        @runners.runner_for_app(app).update_routes if app.started?
      end

      private

      def delete_buildpack_cache(app)
        delete_job = Jobs::Runtime::BlobstoreDelete.new(app.buildpack_cache_key, :buildpack_cache_blobstore)
        Jobs::Enqueuer.new(delete_job, queue: 'cc-generic').enqueue
      end

      def delete_package(app)
        delete_job = Jobs::Runtime::BlobstoreDelete.new(app.guid, :package_blobstore)
        Jobs::Enqueuer.new(delete_job, queue: 'cc-generic').enqueue
      end

      def react_to_state_change(app)
        if !app.started?
          @runners.runner_for_app(app).stop
          return
        end

        if app.needs_staging?
          @stagers.validate_app(app)
          @stagers.stager_for_app(app).stage_app
        else
          @runners.runner_for_app(app).start
        end
      end

      def react_to_instances_change(app)
        @runners.runner_for_app(app).scale if app.started?
      end
    end
  end
end
