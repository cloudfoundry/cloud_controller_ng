# Backfills synthetic WAS_RUNNING usage events (TASK_WAS_RUNNING for tasks) for
# resources that were already running/existing when the keep-running cleanup
# feature was introduced.
#
# Runs from thin Sequel migrations, in batches, like VCAP::BigintMigration.
# Each batch walks the source table by id and commits in its own transaction,
# so no single statement comes near the migration statement timeout. Running it
# again is safe: the NOT EXISTS guards skip resources whose start is already on
# record, and the post-seed repair only adds missing ending events -- it never
# deletes rows a consumer may already have read (see repair_stale_*). Uses only
# raw Sequel, no Cloud Controller models or repositories, because at migration
# time the schema is the contract, not the app code.
# rubocop:disable Metrics/ModuleLength
module VCAP::WasRunningBackfill
  WAS_RUNNING = 'WAS_RUNNING'.freeze
  # Task baselines use a distinct state because task events share the
  # app_usage_events table with app events but carry an empty app_guid -- see
  # Repositories::AppUsageEventRepository::TASK_WAS_RUNNING_EVENT_STATE.
  TASK_WAS_RUNNING = 'TASK_WAS_RUNNING'.freeze
  # The states of normal, API-written usage events, used by the seed guards and
  # the repair. The strings are deliberately copied from the model/repository
  # constants rather than referenced, so migration-time code never loads app
  # classes; a spec asserts the copies stay equal.
  STARTED = 'STARTED'.freeze
  STOPPED = 'STOPPED'.freeze
  TASK_STARTED = 'TASK_STARTED'.freeze
  TASK_STOPPED = 'TASK_STOPPED'.freeze
  CREATED = 'CREATED'.freeze
  UPDATED = 'UPDATED'.freeze
  DELETED = 'DELETED'.freeze
  # Task states that count as "still running", for BOTH the seed filters and
  # the repair predicate. CANCELING is the span between a cancel request and
  # Diego reporting the task dead: the task is still running and still
  # billable, no usage event marks the transition, and the task always ends in
  # FAILED later. Seed and repair must agree on this list. If the seed counted
  # CANCELING and the repair did not, the repair would write a TASK_STOPPED for
  # a task that is still running -- and when the task really stopped, TaskModel
  # would see a stop event already exists and not write the real one.
  RUNNING_TASK_STATES = %w[RUNNING CANCELING].freeze
  DEFAULT_BATCH_SIZE = 1000
  # Only one backfill may run at a time. If two ran at once (say an operator's
  # rake task racing another deploy's seed migrations), both would check "is a
  # stop event missing?" before either had written one, and both would write it
  # -- duplicate endings. A session-scoped database advisory lock prevents
  # that: every caller must hold it while seeding. The seed migrations WAIT for
  # it (a deploy that pauses behind a finishing rake run is harmless; failing
  # the deploy is not), while the rake task fails fast so an operator gets
  # feedback instead of a silent queue. Postgres advisory locks are keyed by a
  # number (this one is the timestamp of the first seed migration); MySQL locks
  # are keyed by name.
  #
  # This is the first advisory lock in this codebase, so a word on why none of
  # the existing locking tools fit. The lockings-table row lock
  # (Locking#lock!, used for the buildpack critical sections) only holds while
  # one transaction stays open, and this job commits once per batch on
  # purpose. The FOR UPDATE SKIP LOCKED claiming in the bigint backfill lets
  # two runs split rows between them, which works there because writing the
  # same row twice is harmless; it cannot stop two runs from both deciding an
  # ending event is missing and both inserting one. Locket is a separate lock
  # service with certificates and heartbeat threads; a migration cannot
  # reasonably depend on it. A session-scoped advisory lock is the one tool
  # that holds across many transactions and frees itself when the session
  # dies. Rails' migration runner serializes concurrent migrations the same
  # way; Sequel has no built-in equivalent.
  ADVISORY_LOCK_KEY = 20_260_601_120_100
  ADVISORY_LOCK_NAME = 'cloud_controller.was_running_backfill'.freeze

  class << self
    # Operators can opt out (e.g. very large foundations, or downstream usage-event
    # consumers that are not yet ready for the WAS_RUNNING state). Mirrors
    # skip_bigint_id_migration. The flag is checked by the seed migrations rather
    # than here, so the 'db:was_running_backfill' rake task can still seed the
    # baseline after a skipped migration has been recorded as applied.
    def skip?
      VCAP::CloudController::Config.config&.get(:skip_was_running_backfill) || false
    rescue VCAP::CloudController::Config::InvalidConfigPath
      false
    end

    def log_skip(logger, kind)
      logger.info("skipping WAS_RUNNING #{kind} usage event backfill (skip_was_running_backfill is set); " \
                  "run 'rake db:was_running_backfill' to seed the baseline later")
    end

    # Holds a session-scoped advisory lock for the duration of the block.
    # db.synchronize pins the current thread to one pooled connection so the
    # acquire, the block's queries, and the release all run on the same
    # database session. With wait: true the acquire blocks until the holder
    # releases; without it, a held lock raises immediately.
    def with_advisory_lock(db, wait: false)
      db.synchronize do
        if wait
          acquire_advisory_lock(db)
        else
          raise 'another WAS_RUNNING backfill is already running (advisory lock is held by another session); try again later' unless try_advisory_lock(db)
        end

        begin
          yield
        ensure
          release_advisory_lock(db)
        end
      end
    end

    def seed_app_usage_events(db, logger, batch_size: DEFAULT_BATCH_SIZE)
      validate_batch_size!(batch_size)
      uuid_fn = uuid_function(db)
      each_batch(db[:processes].where(state: 'STARTED'), batch_size) do |low, high|
        db.run(app_usage_events_insert_sql(uuid_fn, low, high))
        logger.info("backfilled WAS_RUNNING app usage events up to process id #{high}")
      end
      repair_stale_app_usage_events(db, logger, batch_size)
    end

    def seed_service_usage_events(db, logger, batch_size: DEFAULT_BATCH_SIZE)
      validate_batch_size!(batch_size)
      uuid_fn = uuid_function(db)
      each_batch(db[:service_instances], batch_size) do |low, high|
        db.run(service_usage_events_insert_sql(uuid_fn, low, high))
        logger.info("backfilled WAS_RUNNING service usage events up to service_instance id #{high}")
      end
      repair_stale_service_usage_events(db, logger, batch_size)
    end

    def seed_task_usage_events(db, logger, batch_size: DEFAULT_BATCH_SIZE)
      validate_batch_size!(batch_size)
      uuid_fn = uuid_function(db)
      each_batch(db[:tasks].where(state: RUNNING_TASK_STATES), batch_size) do |low, high|
        db.run(task_usage_events_insert_sql(uuid_fn, low, high))
        logger.info("backfilled TASK_WAS_RUNNING app usage events up to task id #{high}")
      end
      repair_stale_task_usage_events(db, logger, batch_size)
    end

    private

    # A batch size below 1 would make each_batch's LIMIT return no rows and the
    # loop exit immediately -- the backfill would report success having seeded
    # nothing. Easy to hit from the rake task ('rake db:was_running_backfill[0]'),
    # so fail loudly instead.
    def validate_batch_size!(batch_size)
      raise ArgumentError.new("batch_size must be a positive integer, got #{batch_size.inspect}") unless batch_size.is_a?(Integer) && batch_size >= 1
    end

    def try_advisory_lock(db)
      case db.database_type
      when :postgres then db.get(Sequel.function(:pg_try_advisory_lock, ADVISORY_LOCK_KEY))
      when :mysql then db.get(Sequel.function(:get_lock, ADVISORY_LOCK_NAME, 0)) == 1
      else raise "unsupported database: #{db.database_type}"
      end
    end

    def acquire_advisory_lock(db)
      case db.database_type
      when :postgres then db.get(Sequel.function(:pg_advisory_lock, ADVISORY_LOCK_KEY))
      # A negative timeout means "wait forever" on MySQL.
      when :mysql then db.get(Sequel.function(:get_lock, ADVISORY_LOCK_NAME, -1))
      else raise "unsupported database: #{db.database_type}"
      end
    end

    def release_advisory_lock(db)
      case db.database_type
      when :postgres then db.get(Sequel.function(:pg_advisory_unlock, ADVISORY_LOCK_KEY))
      when :mysql then db.get(Sequel.function(:release_lock, ADVISORY_LOCK_NAME))
      end
    end

    # The latest-package / latest-droplet subqueries are limited to the batch's
    # apps so they never scan the whole packages/droplets tables, which could
    # blow the migration statement timeout.
    #
    # The INNER JOINs (process -> app -> space -> org; likewise in the service
    # and task seeds below) cannot drop rows: every edge is enforced by a
    # foreign key, so an orphaned source row cannot exist.
    #
    # The COALESCEs are defensive: processes.memory/instances and apps.name are
    # nullable columns whose defaults are normally filled in by the model layer,
    # but the target event columns are NOT NULL — one legacy NULL row written
    # outside the models must not abort the whole migration.
    #
    # previous_state is NULL, not the current state. purge_and_reseed_started_apps!
    # writes previous_state == state (STARTED/STARTED) to mean "no change, current
    # snapshot" — safe only because its state is the real STARTED. Our state is
    # the made-up WAS_RUNNING, so writing STARTED here would claim a
    # STARTED->WAS_RUNNING transition happened, and writing WAS_RUNNING would
    # claim there was an earlier WAS_RUNNING event. Neither is true.
    #
    # The NOT EXISTS guard also skips processes that still have their real
    # STARTED event (the keep-running cleanup keeps it for as long as the
    # process runs). Without that, running the rake task again would give every
    # process started since the last run a second "start" on record, and a
    # consumer that counts starts would bill it twice. Same in the service/task
    # seeds below.
    def app_usage_events_insert_sql(uuid_fn, low, high)
      batch_apps = "SELECT app_guid FROM processes WHERE id > #{low} AND id <= #{high} AND state = 'STARTED'"
      <<~SQL.squish
        INSERT INTO app_usage_events (
          guid, created_at,
          state, previous_state,
          instance_count, previous_instance_count,
          memory_in_mb_per_instance, previous_memory_in_mb_per_instance,
          app_guid, app_name,
          parent_app_guid, parent_app_name,
          process_type,
          space_guid, space_name, org_guid,
          buildpack_guid, buildpack_name,
          package_state, previous_package_state
        )
        SELECT
          #{uuid_fn}, CURRENT_TIMESTAMP,
          '#{WAS_RUNNING}', NULL,
          COALESCE(p.instances, 0), COALESCE(p.instances, 0),
          COALESCE(p.memory, 0), COALESCE(p.memory, 0),
          p.guid, COALESCE(parent_app.name, ''),
          parent_app.guid, COALESCE(parent_app.name, ''),
          p.type,
          spaces.guid, spaces.name, organizations.guid,
          desired_droplet.buildpack_receipt_buildpack_guid, desired_droplet.buildpack_receipt_buildpack,
          CASE
            WHEN latest_droplet.state = 'FAILED' THEN 'FAILED'
            WHEN latest_droplet.state = 'STAGED' AND latest_droplet.guid = parent_app.droplet_guid THEN 'STAGED'
            WHEN latest_package.state = 'FAILED' THEN 'FAILED'
            ELSE 'PENDING'
          END,
          'UNKNOWN'
        FROM processes p
        INNER JOIN apps parent_app ON parent_app.guid = p.app_guid
        INNER JOIN spaces ON spaces.guid = parent_app.space_guid
        INNER JOIN organizations ON organizations.id = spaces.organization_id
        LEFT JOIN droplets desired_droplet ON desired_droplet.guid = parent_app.droplet_guid
        LEFT JOIN (
          SELECT pkg.guid, pkg.app_guid, pkg.state FROM packages pkg
          INNER JOIN (
            SELECT app_guid, MAX(id) AS max_id FROM packages
            WHERE app_guid IN (#{batch_apps}) GROUP BY app_guid
          ) lp_ids ON lp_ids.app_guid = pkg.app_guid AND lp_ids.max_id = pkg.id
        ) latest_package ON latest_package.app_guid = parent_app.guid
        LEFT JOIN (
          SELECT d.guid, d.package_guid, d.state FROM droplets d
          INNER JOIN (
            SELECT package_guid, MAX(id) AS max_id FROM droplets
            WHERE package_guid IN (SELECT guid FROM packages WHERE app_guid IN (#{batch_apps}))
            GROUP BY package_guid
          ) ld_ids ON ld_ids.package_guid = d.package_guid AND ld_ids.max_id = d.id
        ) latest_droplet ON latest_droplet.package_guid = latest_package.guid
        WHERE p.id > #{low} AND p.id <= #{high}
          AND p.state = 'STARTED'
          AND NOT EXISTS (
            SELECT 1 FROM app_usage_events WHERE state IN ('#{WAS_RUNNING}', '#{STARTED}') AND app_guid = p.guid
          )
      SQL
    end

    def service_usage_events_insert_sql(uuid_fn, low, high)
      <<~SQL.squish
        INSERT INTO service_usage_events (
          guid, created_at, state,
          service_instance_guid, service_instance_name, service_instance_type,
          service_plan_guid, service_plan_name,
          service_guid, service_label,
          service_broker_name, service_broker_guid,
          space_guid, space_name, org_guid
        )
        SELECT
          #{uuid_fn}, CURRENT_TIMESTAMP, '#{WAS_RUNNING}',
          service_instances.guid, service_instances.name,
          CASE WHEN service_instances.is_gateway_service THEN 'managed_service_instance' ELSE 'user_provided_service_instance' END,
          service_plans.guid, service_plans.name,
          services.guid, services.label,
          service_brokers.name, service_brokers.guid,
          spaces.guid, spaces.name, organizations.guid
        FROM service_instances
        INNER JOIN spaces ON spaces.id = service_instances.space_id
        INNER JOIN organizations ON organizations.id = spaces.organization_id
        LEFT OUTER JOIN service_plans ON service_plans.id = service_instances.service_plan_id
        LEFT OUTER JOIN services ON services.id = service_plans.service_id
        LEFT OUTER JOIN service_brokers ON service_brokers.id = services.service_broker_id
        WHERE service_instances.id > #{low} AND service_instances.id <= #{high}
          AND NOT EXISTS (
            SELECT 1 FROM service_usage_events
            WHERE state IN ('#{WAS_RUNNING}', '#{CREATED}', '#{UPDATED}') AND service_instance_guid = service_instances.guid
          )
      SQL
    end

    # Mirrors AppUsageEventRepository#create_from_task: task events carry an
    # empty app_guid/app_name and are keyed by task_guid instead. The COALESCE
    # on memory_in_mb is defensive -- it is a nullable legacy column whose
    # default is normally filled in by the model layer.
    #
    # previous_state is NULL for the same reason as the app baseline (see
    # app_usage_events_insert_sql): TASK_WAS_RUNNING is made up, so writing
    # RUNNING here would claim a RUNNING->TASK_WAS_RUNNING transition happened.
    # It didn't.
    def task_usage_events_insert_sql(uuid_fn, low, high)
      <<~SQL.squish
        INSERT INTO app_usage_events (
          guid, created_at,
          state, previous_state,
          instance_count, previous_instance_count,
          memory_in_mb_per_instance, previous_memory_in_mb_per_instance,
          app_guid, app_name,
          parent_app_guid, parent_app_name,
          space_guid, space_name, org_guid,
          package_state, previous_package_state,
          task_guid, task_name
        )
        SELECT
          #{uuid_fn}, CURRENT_TIMESTAMP,
          '#{TASK_WAS_RUNNING}', NULL,
          1, 1,
          COALESCE(t.memory_in_mb, 0), COALESCE(t.memory_in_mb, 0),
          '', '',
          parent_app.guid, COALESCE(parent_app.name, ''),
          spaces.guid, spaces.name, organizations.guid,
          'STAGED', 'STAGED',
          t.guid, t.name
        FROM tasks t
        INNER JOIN apps parent_app ON parent_app.guid = t.app_guid
        INNER JOIN spaces ON spaces.guid = parent_app.space_guid
        INNER JOIN organizations ON organizations.id = spaces.organization_id
        WHERE t.id > #{low} AND t.id <= #{high}
          AND t.state IN (#{running_task_states_sql})
          AND NOT EXISTS (
            SELECT 1 FROM app_usage_events WHERE state IN ('#{TASK_WAS_RUNNING}', '#{TASK_STARTED}') AND task_guid = t.guid
          )
      SQL
    end

    # The API stays live while the backfill runs, so a seed batch can race a
    # concurrent stop or delete: the batch's snapshot still sees the resource
    # as running and writes a WAS_RUNNING row for something that is already
    # gone -- or whose stop event landed earlier in the table, with a lower id.
    # Left alone, the keep-running cleanup would keep that row forever and
    # consumers would bill a dead resource as still running.
    #
    # Deleting such rows would not fix this. Consumers read these tables
    # forward, by id, and keep what they read: a poller may already have the
    # baseline, and for tasks a TASK_STOPPED may already have been written
    # against it. You can delete a row; you cannot make a consumer un-read it.
    # And deleting it would leave any stop event that points at it dangling.
    #
    # So instead of deleting, repair: for every baseline whose resource is no
    # longer running and that has no later ending event, add the missing ending
    # event. It is built from the baseline row itself, which carries every NOT
    # NULL column an ending needs -- necessary, because the resource row may be
    # gone entirely (for stale service baselines it always is). Once an ending
    # is added, the baseline no longer counts as unpaired, so running the
    # repair again changes nothing.
    #
    # Two properties of the added ending, both deliberate. Its created_at is
    # the repair time, not the true stop time, so a consumer may overbill by
    # that gap -- a bounded error that ends, which beats a missing ending
    # billed forever. And its previous_state is the baseline's state, which no
    # normal ending ever carries, so repaired endings are easy to tell apart.
    def repair_stale_app_usage_events(db, logger, batch_size)
      uuid_fn = uuid_function(db)
      stale = db[:app_usage_events].where(state: WAS_RUNNING).where(Sequel.lit(stale_app_baseline_predicates('app_usage_events')))
      repaired = batch_repair(db, stale, batch_size) { |ids| app_usage_events_repair_sql(uuid_fn, ids) }
      logger.info("added #{repaired} STOPPED usage events to pair stale WAS_RUNNING baselines") if repaired.positive?
    end

    def repair_stale_service_usage_events(db, logger, batch_size)
      uuid_fn = uuid_function(db)
      stale = db[:service_usage_events].where(state: WAS_RUNNING).where(Sequel.lit(stale_service_baseline_predicates('service_usage_events')))
      repaired = batch_repair(db, stale, batch_size) { |ids| service_usage_events_repair_sql(uuid_fn, ids) }
      logger.info("added #{repaired} DELETED usage events to pair stale WAS_RUNNING baselines") if repaired.positive?
    end

    def repair_stale_task_usage_events(db, logger, batch_size)
      uuid_fn = uuid_function(db)
      stale = db[:app_usage_events].where(state: TASK_WAS_RUNNING).where(Sequel.lit(stale_task_baseline_predicates('app_usage_events')))
      repaired = batch_repair(db, stale, batch_size) { |ids| task_usage_events_repair_sql(uuid_fn, ids) }
      logger.info("added #{repaired} TASK_STOPPED usage events to pair stale TASK_WAS_RUNNING baselines") if repaired.positive?
    end

    # The test for a stale, unpaired baseline: the resource is not running (or
    # is gone), AND no later ending event -- one with a higher id -- exists for
    # it. The second half is what makes re-runs safe: a baseline whose resource
    # stopped normally already has its ending event and is left alone.
    # `qualifier` names the baseline row -- the table itself in the
    # id-collecting SELECT, its alias in the INSERT..SELECT -- so both queries
    # apply exactly the same test and cannot drift apart.
    def stale_app_baseline_predicates(qualifier)
      "NOT EXISTS (SELECT 1 FROM processes WHERE processes.guid = #{qualifier}.app_guid AND processes.state = 'STARTED') " \
        "AND NOT EXISTS (SELECT 1 FROM app_usage_events endings WHERE endings.state = '#{STOPPED}' AND endings.app_guid = #{qualifier}.app_guid AND endings.id > #{qualifier}.id)"
    end

    def stale_service_baseline_predicates(qualifier)
      "NOT EXISTS (SELECT 1 FROM service_instances WHERE service_instances.guid = #{qualifier}.service_instance_guid) " \
        'AND NOT EXISTS (SELECT 1 FROM service_usage_events endings ' \
        "WHERE endings.state = '#{DELETED}' AND endings.service_instance_guid = #{qualifier}.service_instance_guid AND endings.id > #{qualifier}.id)"
    end

    def stale_task_baseline_predicates(qualifier)
      "NOT EXISTS (SELECT 1 FROM tasks WHERE tasks.guid = #{qualifier}.task_guid AND tasks.state IN (#{running_task_states_sql})) " \
        'AND NOT EXISTS (SELECT 1 FROM app_usage_events endings ' \
        "WHERE endings.state = '#{TASK_STOPPED}' AND endings.task_guid = #{qualifier}.task_guid AND endings.id > #{qualifier}.id)"
    end

    def running_task_states_sql
      RUNNING_TASK_STATES.map { |state| "'#{state}'" }.join(', ')
    end

    def app_usage_events_repair_sql(uuid_fn, ids)
      <<~SQL.squish
        INSERT INTO app_usage_events (
          guid, created_at,
          state, previous_state,
          instance_count, previous_instance_count,
          memory_in_mb_per_instance, previous_memory_in_mb_per_instance,
          app_guid, app_name,
          parent_app_guid, parent_app_name,
          process_type,
          space_guid, space_name, org_guid,
          buildpack_guid, buildpack_name,
          package_state, previous_package_state
        )
        SELECT
          #{uuid_fn}, CURRENT_TIMESTAMP,
          '#{STOPPED}', b.state,
          b.instance_count, b.previous_instance_count,
          b.memory_in_mb_per_instance, b.previous_memory_in_mb_per_instance,
          b.app_guid, b.app_name,
          b.parent_app_guid, b.parent_app_name,
          b.process_type,
          b.space_guid, b.space_name, b.org_guid,
          b.buildpack_guid, b.buildpack_name,
          b.package_state, b.previous_package_state
        FROM app_usage_events b
        WHERE b.id IN (#{ids.join(', ')})
          AND b.state = '#{WAS_RUNNING}'
          AND #{stale_app_baseline_predicates('b')}
      SQL
    end

    def service_usage_events_repair_sql(uuid_fn, ids)
      <<~SQL.squish
        INSERT INTO service_usage_events (
          guid, created_at, state,
          service_instance_guid, service_instance_name, service_instance_type,
          service_plan_guid, service_plan_name,
          service_guid, service_label,
          service_broker_name, service_broker_guid,
          space_guid, space_name, org_guid
        )
        SELECT
          #{uuid_fn}, CURRENT_TIMESTAMP, '#{DELETED}',
          b.service_instance_guid, b.service_instance_name, b.service_instance_type,
          b.service_plan_guid, b.service_plan_name,
          b.service_guid, b.service_label,
          b.service_broker_name, b.service_broker_guid,
          b.space_guid, b.space_name, b.org_guid
        FROM service_usage_events b
        WHERE b.id IN (#{ids.join(', ')})
          AND b.state = '#{WAS_RUNNING}'
          AND #{stale_service_baseline_predicates('b')}
      SQL
    end

    def task_usage_events_repair_sql(uuid_fn, ids)
      <<~SQL.squish
        INSERT INTO app_usage_events (
          guid, created_at,
          state, previous_state,
          instance_count, previous_instance_count,
          memory_in_mb_per_instance, previous_memory_in_mb_per_instance,
          app_guid, app_name,
          parent_app_guid, parent_app_name,
          space_guid, space_name, org_guid,
          package_state, previous_package_state,
          task_guid, task_name
        )
        SELECT
          #{uuid_fn}, CURRENT_TIMESTAMP,
          '#{TASK_STOPPED}', b.state,
          b.instance_count, b.previous_instance_count,
          b.memory_in_mb_per_instance, b.previous_memory_in_mb_per_instance,
          b.app_guid, b.app_name,
          b.parent_app_guid, b.parent_app_name,
          b.space_guid, b.space_name, b.org_guid,
          b.package_state, b.previous_package_state,
          b.task_guid, b.task_name
        FROM app_usage_events b
        WHERE b.id IN (#{ids.join(', ')})
          AND b.state = '#{TASK_WAS_RUNNING}'
          AND #{stale_task_baseline_predicates('b')}
      SQL
    end

    # Walk a source dataset in id order, one batch at a time, yielding each
    # batch's id bounds (exclusive low, inclusive high) inside its own
    # transaction.
    def each_batch(source, batch_size)
      cursor = 0
      loop do
        high = source.where(Sequel.lit('id > ?', cursor)).order(:id).limit(batch_size).select(:id).max(:id)
        break if high.nil?

        # READ COMMITTED keeps MySQL's INSERT..SELECT from taking shared next-key
        # locks on every scanned source row while the API serves traffic (safe:
        # CF MySQL releases run with binlog_format=ROW). On Postgres it is the
        # default isolation level anyway.
        source.db.transaction(isolation: :committed) { yield(cursor, high) }
        cursor = high
      end
    end

    # Add the missing ending events in id-keyed batches, so no single statement
    # (or the locks it holds) grows big enough to risk the migration statement
    # timeout. The INSERT..SELECT re-checks the staleness test itself, so a
    # resource that came back -- or got its real ending -- between collecting
    # the ids and inserting is simply skipped. Each added ending removes its
    # baseline from the stale set, so the loop always finishes; if a whole
    # batch got invalidated in flight, stop rather than risk selecting the same
    # ids forever (the next backfill run picks up whatever remains).
    def batch_repair(db, stale_baselines, batch_size)
      repaired = 0
      loop do
        ids = stale_baselines.limit(batch_size).select_map(:id)
        break if ids.empty?

        # READ COMMITTED for the same reason as the seed batches (see each_batch).
        inserted = db.transaction(isolation: :committed) { db.execute_dui(yield(ids)) }
        break if inserted.zero?

        repaired += inserted
      end
      repaired
    end

    def uuid_function(db)
      case db.database_type
      when :postgres then 'get_uuid()'
      when :mysql then 'UUID()'
      else raise "unsupported database: #{db.database_type}"
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
