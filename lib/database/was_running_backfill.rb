# Backfills synthetic WAS_RUNNING usage events (TASK_WAS_RUNNING for tasks) for
# resources that were already running/existing when the keep-running cleanup
# feature was introduced.
#
# Run from thin Sequel migrations as a batched, idempotent, resumable operation
# (mirrors VCAP::BigintMigration): each batch is keyset-paginated by source-table
# id and runs in its own transaction, well under the migration statement timeout.
# Re-running is safe via the NOT EXISTS guard. Uses only raw Sequel — no Cloud
# Controller models/repositories — because the schema, not the app code, is the
# contract at migration time.
# rubocop:disable Metrics/ModuleLength
module VCAP::WasRunningBackfill
  WAS_RUNNING = 'WAS_RUNNING'.freeze
  # Task baselines use a distinct state because task events share the
  # app_usage_events table with app events but carry an empty app_guid -- see
  # Repositories::AppUsageEventRepository::TASK_WAS_RUNNING_EVENT_STATE.
  TASK_WAS_RUNNING = 'TASK_WAS_RUNNING'.freeze
  DEFAULT_BATCH_SIZE = 1000

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

    def seed_app_usage_events(db, logger, batch_size: DEFAULT_BATCH_SIZE)
      uuid_fn = uuid_function(db)
      each_batch(db[:processes].where(state: 'STARTED'), batch_size) do |low, high|
        db.run(app_usage_events_insert_sql(uuid_fn, low, high))
        logger.info("backfilled WAS_RUNNING app usage events up to process id #{high}")
      end
      sweep_stale_app_usage_events(db, logger, batch_size)
    end

    def seed_service_usage_events(db, logger, batch_size: DEFAULT_BATCH_SIZE)
      uuid_fn = uuid_function(db)
      each_batch(db[:service_instances], batch_size) do |low, high|
        db.run(service_usage_events_insert_sql(uuid_fn, low, high))
        logger.info("backfilled WAS_RUNNING service usage events up to service_instance id #{high}")
      end
      sweep_stale_service_usage_events(db, logger, batch_size)
    end

    def seed_task_usage_events(db, logger, batch_size: DEFAULT_BATCH_SIZE)
      uuid_fn = uuid_function(db)
      each_batch(db[:tasks].where(state: 'RUNNING'), batch_size) do |low, high|
        db.run(task_usage_events_insert_sql(uuid_fn, low, high))
        logger.info("backfilled TASK_WAS_RUNNING app usage events up to task id #{high}")
      end
      sweep_stale_task_usage_events(db, logger, batch_size)
    end

    def delete_app_usage_events(db, batch_size: DEFAULT_BATCH_SIZE)
      delete_was_running(db, :app_usage_events, batch_size, state: WAS_RUNNING)
    end

    def delete_service_usage_events(db, batch_size: DEFAULT_BATCH_SIZE)
      delete_was_running(db, :service_usage_events, batch_size, state: WAS_RUNNING)
    end

    def delete_task_usage_events(db, batch_size: DEFAULT_BATCH_SIZE)
      delete_was_running(db, :app_usage_events, batch_size, state: TASK_WAS_RUNNING)
    end

    private

    # The latest-package / latest-droplet aggregates are scoped to the batch's apps
    # so they never scan the whole packages/droplets tables (the cost that would
    # otherwise blow the migration statement timeout).
    #
    # The COALESCEs are defensive: processes.memory/instances and apps.name are
    # nullable columns whose defaults are normally backfilled by the model layer,
    # but the target event columns are NOT NULL — one legacy NULL row written
    # outside the models must not abort the whole migration.
    #
    # previous_state is NULL, not the current state. purge_and_reseed_started_apps!
    # writes previous_state == state (STARTED/STARTED) to mean "no change, current
    # snapshot" — safe only because its state is the real STARTED. Our state is the
    # synthetic WAS_RUNNING, so STARTED here would invent a STARTED->WAS_RUNNING
    # transition, and WAS_RUNNING would imply an earlier WAS_RUNNING event that
    # never actually happened.
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
            SELECT 1 FROM app_usage_events WHERE state = '#{WAS_RUNNING}' AND app_guid = p.guid
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
            SELECT 1 FROM service_usage_events WHERE state = '#{WAS_RUNNING}' AND service_instance_guid = service_instances.guid
          )
      SQL
    end

    # Mirrors AppUsageEventRepository#create_from_task: task events carry an
    # empty app_guid/app_name and are keyed by task_guid instead. The COALESCE
    # on memory_in_mb is defensive -- it is a nullable legacy column whose
    # default is normally backfilled by the model layer.
    #
    # previous_state is NULL for the same reason as the app baseline (see
    # app_usage_events_insert_sql): TASK_WAS_RUNNING is synthetic, so RUNNING here
    # would invent a RUNNING->TASK_WAS_RUNNING transition that never happened.
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
          AND t.state = 'RUNNING'
          AND NOT EXISTS (
            SELECT 1 FROM app_usage_events WHERE state = '#{TASK_WAS_RUNNING}' AND task_guid = t.guid
          )
      SQL
    end

    # The API stays live while the backfill runs, so a batch's INSERT..SELECT can
    # race a concurrent stop/delete: the statement's snapshot still sees the
    # resource as running and inserts a WAS_RUNNING row with a HIGHER id than the
    # concurrent STOPPED/DELETED event. No later ending event would ever arrive
    # for that resource, so the keep-running cleanup would retain the row forever
    # and consumers would read the stopped resource as still running. Sweep such
    # rows afterwards in id-keyed batches (like the rollback deletes) -- the
    # predicate is re-checked against current resource state each batch, and no
    # single DELETE (or its lock hold) grows large enough to risk the timeout.
    def sweep_stale_app_usage_events(db, logger, batch_size)
      stale = db[:app_usage_events].
              where(state: WAS_RUNNING).
              where(Sequel.lit("NOT EXISTS (SELECT 1 FROM processes WHERE processes.guid = app_usage_events.app_guid AND processes.state = 'STARTED')"))
      deleted = batch_delete(db, :app_usage_events, stale, batch_size)
      logger.info("swept #{deleted} stale WAS_RUNNING app usage events") if deleted.positive?
    end

    def sweep_stale_service_usage_events(db, logger, batch_size)
      stale = db[:service_usage_events].
              where(state: WAS_RUNNING).
              where(Sequel.lit('NOT EXISTS (SELECT 1 FROM service_instances WHERE service_instances.guid = service_usage_events.service_instance_guid)'))
      deleted = batch_delete(db, :service_usage_events, stale, batch_size)
      logger.info("swept #{deleted} stale WAS_RUNNING service usage events") if deleted.positive?
    end

    def sweep_stale_task_usage_events(db, logger, batch_size)
      stale = db[:app_usage_events].
              where(state: TASK_WAS_RUNNING).
              where(Sequel.lit("NOT EXISTS (SELECT 1 FROM tasks WHERE tasks.guid = app_usage_events.task_guid AND tasks.state = 'RUNNING')"))
      deleted = batch_delete(db, :app_usage_events, stale, batch_size)
      logger.info("swept #{deleted} stale TASK_WAS_RUNNING app usage events") if deleted.positive?
    end

    # Keyset-paginate over a source dataset by id, yielding the (exclusive-low,
    # inclusive-high) id bounds of each batch inside its own transaction.
    def each_batch(source, batch_size)
      cursor = 0
      loop do
        high = source.where(Sequel.lit('id > ?', cursor)).order(:id).limit(batch_size).max(:id)
        break if high.nil?

        # READ COMMITTED keeps MySQL's INSERT..SELECT from taking shared next-key
        # locks on every scanned source row while the API serves traffic (safe:
        # CF MySQL releases run with binlog_format=ROW). On Postgres it is the
        # default isolation level anyway.
        source.db.transaction(isolation: :committed) { yield(cursor, high) }
        cursor = high
      end
    end

    # Delete every row matching `dataset` in batches of `batch_size` ids so
    # neither the statement nor its lock hold ever grows large enough to risk the
    # migration statement timeout. Returns the number of rows deleted. Re-selecting
    # the dataset each pass is what lets the sweeps re-check current resource state.
    def batch_delete(db, table, dataset, batch_size)
      deleted = 0
      loop do
        ids = dataset.limit(batch_size).select_map(:id)
        break if ids.empty?

        deleted += db[table].where(id: ids).delete
      end
      deleted
    end

    def delete_was_running(db, table, batch_size, state:)
      batch_delete(db, table, db[table].where(state: state), batch_size)
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
