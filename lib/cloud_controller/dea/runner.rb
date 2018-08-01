module VCAP::CloudController
  module Dea
    class Runner
      def initialize(app, config, blobstore_url_generator, message_bus, dea_pool)
        @logger ||= Steno.logger('cc.dea.backend')
        @app = app
        @config = config
        @message_bus = message_bus
        @dea_pool = dea_pool
        @blobstore_url_generator = blobstore_url_generator
      end

      def scale
        changes = @app.previous_changes
        delta = changes[:instances][1] - changes[:instances][0]

        Client.change_running_instances(@app, delta)
      end

      def start(staging_result={})
        started_instances = staging_result[:started_instances] || 0
        AppStarterTask.new(@app, @blobstore_url_generator, @config).start(instances_to_start: @app.instances - started_instances)
      end

      def stop
        app_stopper = AppStopper.new(@message_bus)
        app_stopper.publish_stop(droplet: @app.guid)
      end

      def update_routes
        Client.update_uris(@app)
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
