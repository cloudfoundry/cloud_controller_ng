require 'timeout'

class DBMigrator
  MIGRATIONS_DIR = File.expand_path('../../db', File.dirname(__FILE__))
  SEQUEL_MIGRATIONS = File.join(MIGRATIONS_DIR, 'migrations')

  def self.from_config(config, db_logger)
    config.load_db_encryption_key
    db = VCAP::CloudController::DB.connect(config.get(:db), db_logger)
    new(db, config.get(:max_migration_duration_in_minutes), config.get(:max_migration_statement_runtime_in_seconds), config.get(:migration_psql_worker_memory_kb))
  end

  def initialize(db, max_migration_duration_in_minutes=nil, max_migration_statement_runtime_in_seconds=nil, migration_psql_worker_memory_kb=nil)
    @db = db
    @timeout_in_minutes = default_two_weeks(max_migration_duration_in_minutes)

    @max_statement_runtime_in_milliseconds = if max_migration_statement_runtime_in_seconds.nil? || max_migration_statement_runtime_in_seconds <= 0
                                               VCAP::Migration::PSQL_DEFAULT_STATEMENT_TIMEOUT
                                             else
                                               max_migration_statement_runtime_in_seconds * 1000
                                             end

    return unless @db.database_type == :postgres

    @db.run("SET statement_timeout TO #{@max_statement_runtime_in_milliseconds}")
    @db.run("SET work_mem = #{migration_psql_worker_memory_kb}") unless migration_psql_worker_memory_kb.nil?
  end

  def apply_migrations(opts={})
    Sequel.extension :migration
    require 'vcap/sequel_case_insensitive_string_monkeypatch'

    if ENV.fetch('WITH_BENCHMARK', false)
      # rubocop:disable Rails/Output
      puts('######################################')
      puts('# Starting migrations with benchmark #')
      puts('######################################')
      require 'benchmark'
      bm_output = Benchmark.measure { Sequel::Migrator.run(@db, SEQUEL_MIGRATIONS, opts) }
      puts('###########')
      puts('# Results #')
      puts('###########')
      puts("Total time for all migrations: #{bm_output.total} seconds")
      puts("System time for all migrations: #{bm_output.stime} seconds")
      puts("User time for all migrations: #{bm_output.utime} seconds")
      puts("Real time for all migrations: #{bm_output.real} seconds")
      # rubocop:enable Rails/Output
    else
      Sequel::Migrator.run(@db, SEQUEL_MIGRATIONS, opts)
    end
  end

  def rollback(number_to_rollback)
    recent_migrations = @db[:schema_migrations].order(Sequel.desc(:filename)).limit(number_to_rollback + 1).all
    recent_migrations = recent_migrations.collect { |hash| hash[:filename].split('_', 2).first.to_i }
    apply_migrations(current: recent_migrations.first, target: recent_migrations.last)
  end

  def wait_for_migrations!
    Sequel.extension :migration
    logger = Steno.logger('cc.db.wait_until_current')

    logger.info('waiting indefinitely for database schema to be current') unless db_is_current_or_newer_than_local_migrations?
    timeout_message = 'ccdb.max_migration_duration_in_minutes exceeded'
    Timeout.timeout(@timeout_in_minutes * 60, message: timeout_message) do
      sleep(1) until db_is_current_or_newer_than_local_migrations?
    end
    logger.info('database schema is as new or newer than locally available migrations')
  end

  private

  TWO_WEEKS = 20_160
  def default_two_weeks(duration_in_minutes)
    return TWO_WEEKS if duration_in_minutes.nil?

    duration_in_minutes
  end

  def db_is_current_or_newer_than_local_migrations?
    Sequel::Migrator.is_current?(@db, SEQUEL_MIGRATIONS, allow_missing_migration_files: true)
  end
end
