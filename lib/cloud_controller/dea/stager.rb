module VCAP::CloudController
  module Dea
    class Stager
      def initialize(app, config, message_bus, dea_pool, runners=CloudController::DependencyLocator.instance.runners)
        @app         = app
        @config      = config
        @message_bus = message_bus
        @dea_pool    = dea_pool
        @runners     = runners
      end

      def stage
        @app.last_stager_response = stager_task.stage do |staging_result|
          @runners.runner_for_app(@app).start(staging_result)
        end
      end

      def staging_complete(_, response)
        stager_task.handle_http_response(response) do |staging_result|
          @runners.runner_for_app(@app).start(staging_result)
        end
      end

      def stop_stage
        nil
      end

      private

      def stager_task
        @task ||= AppStagerTask.new(@config, @message_bus, @app, @dea_pool, CloudController::DependencyLocator.instance.blobstore_url_generator)
      end
    end
  end
end
