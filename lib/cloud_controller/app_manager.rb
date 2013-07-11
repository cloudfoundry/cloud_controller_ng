# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"
require "cloud_controller/multi_response_message_bus_request"

module VCAP::CloudController
  module AppManager
    class << self
      attr_reader :config, :message_bus, :stager_pool

      def configure(config, message_bus, stager_pool)
        @config = config
        @message_bus = message_bus
        @stager_pool = stager_pool
      end

      def run
        stager_pool.register_subscriptions
      end

      def delete_droplet(app)
        Staging.delete_droplet(app)
      end

      def stop_droplet(app)
        DeaClient.stop(app) if app.started?
      end

      def app_changed(app, changes)
        if changes.has_key?(:state)
          react_to_state_change(app)
        elsif changes.has_key?(:instances)
          delta = changes[:instances][1] - changes[:instances][0]
          react_to_instances_change(app, delta)
        end
      end

      private

      def stage_app(app, &completion_callback)
        if app.package_hash.nil? || app.package_hash.empty?
          raise Errors::AppPackageInvalid, "The app package hash is empty"
        end

        task = AppStagerTask.new(config, message_bus, app, stager_pool)
        task.stage(&completion_callback)
      end

      def stage_if_needed(app, &success_callback)
        if app.needs_staging?
          app.last_stager_response = stage_app(app, &success_callback)
        else
          success_callback.call
        end
      end

      def react_to_state_change(app)
        if app.started?
          stage_if_needed(app) do
            DeaClient.start(app)
            send_droplet_updated_message(app)
          end
        else
          DeaClient.stop(app)
          send_droplet_updated_message(app)
        end
      end

      def react_to_instances_change(app, delta)
        if app.started?
          stage_if_needed(app) do
            DeaClient.change_running_instances(app, delta)
            send_droplet_updated_message(app)
          end
        end
      end

      def send_droplet_updated_message(app)
        HealthManagerClient.notify_app_updated(app.guid)
      end
    end
  end
end
