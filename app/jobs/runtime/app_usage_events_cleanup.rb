module VCAP::CloudController
  module Jobs
    module Runtime
      class AppUsageEventsCleanup < Struct.new(:prune_threshold_in_days)
        def perform
          logger = Steno.logger("cc.background")

          events_to_prune = AppUsageEvent.dataset.where("created_at < ?", prune_threshold_in_days.days.ago)
          pruned_event_count = events_to_prune.count
          events_to_prune.delete

          logger.info("Ran AppUsageEventsCleanup, deleted #{pruned_event_count} events")
        end
      end
    end
  end
end
