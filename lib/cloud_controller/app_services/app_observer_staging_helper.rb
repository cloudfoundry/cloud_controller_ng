module VCAP::CloudController
  module AppObserverStagingHelper
    class << self
      def stage_app(app)
        droplet_creator = DropletCreate.new(
          actor:       SecurityContext.current_user,
          actor_email: SecurityContext.current_user_email
        )

        message = DropletCreateMessage.new({
          staging_memory_in_mb: app.memory,
          staging_disk_in_mb:   app.disk_quota
        })

        lifecycle = LifecycleProvider.provide(app.package, message)

        start_after_staging = true
        droplet_creator.create_and_stage(app.package, lifecycle, message, start_after_staging)

        app.last_stager_response = droplet_creator.staging_response
      end
    end
  end
end
