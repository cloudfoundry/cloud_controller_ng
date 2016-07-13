module VCAP::CloudController
  module Dea
    class Stager
      def initialize(package, config, message_bus, dea_pool, runners=CloudController::DependencyLocator.instance.runners)
        @package     = package
        @config      = config
        @message_bus = message_bus
        @dea_pool    = dea_pool
        @runners     = runners
        @app         = package.app.web_process
      end

      def stage(staging_details)
        @droplet = staging_details.droplet

        stager_task.stage do |staging_result|
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
        @task ||= AppStagerTask.new(@config, @message_bus, @droplet, @dea_pool, CloudController::DependencyLocator.instance.blobstore_url_generator)
      end
    end
  end
end
