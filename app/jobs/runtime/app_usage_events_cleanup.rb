module VCAP::CloudController
  module Jobs
    module Runtime
      class AppUsageEventsCleanup
        def perform
          logger = Steno.logger("cc.background")

          AppUsageEvent.dataset.where("created_at < ?", 31.days.ago).delete

          logger.info("Ran AppUsageEventsCleanup, deleted 0 events")
        end
      end
    end
  end
end
