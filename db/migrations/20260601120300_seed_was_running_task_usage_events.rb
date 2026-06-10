require 'database/was_running_backfill'

Sequel.migration do
  no_transaction # backfill manages its own per-batch transactions

  up do
    logger = Steno.logger('cc.backfill.was_running')
    if VCAP::WasRunningBackfill.skip?
      VCAP::WasRunningBackfill.log_skip(logger, 'task')
    else
      # wait: an operator's 'rake db:was_running_backfill' may be running; a
      # deploy that briefly pauses behind it is harmless, failing it is not.
      VCAP::WasRunningBackfill.with_advisory_lock(self, wait: true) do
        VCAP::WasRunningBackfill.seed_task_usage_events(self, logger)
      end
    end
  end

  down do
    # Deliberately a no-op. Consumers may already have read the seeded rows,
    # and deleting a row cannot make a consumer un-read it -- it would only
    # leave any later TASK_STOPPED events without a start event to pair with.
    # Worse: a task's stop event is only written when the task has recorded
    # start evidence, and these rows ARE that evidence for tasks whose
    # TASK_STARTED the cleanup already deleted. Remove them and those tasks'
    # eventual stops are silently swallowed. Leaving the rows is safe:
    # re-running the migration or the 'db:was_running_backfill' rake task
    # skips tasks that already have a baseline.
  end
end
