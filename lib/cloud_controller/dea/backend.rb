module VCAP::CloudController
  module Dea
    class Backend
      def initialize(app, message_bus)
        @logger ||= Steno.logger("cc.dea.backend")
        @app = app
        @message_bus = message_bus
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
    end
  end
end
