module VCAP::CloudController
  module Dea
    class Stager
      def initialize(app, config, message_bus, dea_pool, runners)
        @app         = app
        @config      = config
        @message_bus = message_bus
        @dea_pool    = dea_pool
        @runners     = runners
      end

      def stage
        blobstore_url_generator = CloudController::DependencyLocator.instance.blobstore_url_generator
        task = AppStagerTask.new(@config, @message_bus, @app, @dea_pool, blobstore_url_generator)

        @app.last_stager_response = task.stage do |staging_result|
          @runners.runner_for_app(@app).start(staging_result)
        end
      end

      def staging_complete(_, _)
        raise NotImplementedError
      end
    end
  end
end
