require 'database/was_running_backfill'

Sequel.migration do
  no_transaction # backfill manages its own per-batch transactions

  up do
    logger = Steno.logger('cc.backfill.was_running')
    if VCAP::WasRunningBackfill.skip?
      VCAP::WasRunningBackfill.log_skip(logger, 'app')
    else
      VCAP::WasRunningBackfill.seed_app_usage_events(self, logger)
    end
  end

  down do
    VCAP::WasRunningBackfill.delete_app_usage_events(self)
  end
end
