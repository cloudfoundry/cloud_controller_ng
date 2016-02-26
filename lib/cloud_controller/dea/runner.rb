module VCAP::CloudController
  module Dea
    class Runner
      def initialize(app, config, message_bus, dea_pool)
        @logger ||= Steno.logger('cc.dea.backend')
        @app = app
        @config = config
        @message_bus = message_bus
        @dea_pool = dea_pool
      end

      def scale
        changes = @app.previous_changes
        delta = changes[:instances][1] - changes[:instances][0]

        Client.change_running_instances(@app, delta)
      end

      def start(staging_result={})
        started_instances = staging_result[:started_instances] || 0
        Client.start(@app, instances_to_start: @app.instances - started_instances)
      end

      def stop
        app_stopper = AppStopper.new(@message_bus)
        app_stopper.publish_stop(droplet: @app.guid)
      end

      def update_routes
      end

      def desire_app_message
        raise NotImplementedError
      end

      def stop_index(index)
        Client.stop_indices(@app, [index])
      end
    end
  end
end
