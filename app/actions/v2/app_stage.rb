module VCAP::CloudController
  module V2
    class AppStage
      def initialize(user:, user_email:, stagers:)
        @user       = user
        @user_email = user_email
        @stagers    = stagers
      end

      def stage(app)
        @stagers.validate_app(app)

        droplet_creator = DropletCreate.new(actor: @user, actor_email: @user_email)

        message = DropletCreateMessage.new({
          staging_memory_in_mb: app.memory,
          staging_disk_in_mb:   app.disk_quota
        })

        lifecycle = LifecycleProvider.provide(app.package, message)

        start_after_staging = true
        droplet_creator.create_and_stage(app.package, lifecycle, message, start_after_staging)

        app.last_stager_response = droplet_creator.staging_response

      # TODO: make sure this is in the right place and add tests
      rescue Diego::Runner::CannotCommunicateWithDiegoError => e
        logger.error("failed communicating with diego backend: #{e.message}")
      end
    end
  end
end
