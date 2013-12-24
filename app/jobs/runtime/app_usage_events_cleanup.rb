module VCAP::CloudController
  module Jobs
    module Runtime
      class AppUsageEventsCleanup
        def perform
          logger = Steno.logger("cc.background")
          logger.info("Did nothing AppUsageEventsCleanup")
        end
      end
    end
  end
end
