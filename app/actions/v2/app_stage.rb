module VCAP::CloudController
  module V2
    class AppStage
      def initialize(stagers:)
        @stagers = stagers
      end

      def stage(app)
        @stagers.validate_app(app)

        message = DropletCreateMessage.new({
          staging_memory_in_mb: app.memory,
          staging_disk_in_mb:   app.disk_quota
        })

        lifecycle = LifecycleProvider.provide(app.latest_package, message)

        droplet_creator = DropletCreate.new
        droplet_creator.create_and_stage_without_event(
          package:             app.latest_package,
          lifecycle:           lifecycle,
          message:             message,
          start_after_staging: true
        )

        app.last_stager_response = droplet_creator.staging_response
      rescue Diego::Runner::CannotCommunicateWithDiegoError => e
        logger.error("failed communicating with diego backend: #{e.message}")
      end
    end
  end
end
