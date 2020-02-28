require 'timeout'

class DBMigrator
  MIGRATIONS_DIR = File.expand_path('../../db', File.dirname(__FILE__))
  SEQUEL_MIGRATIONS = File.join(MIGRATIONS_DIR, 'migrations')

  def self.from_config(config, db_logger)
    VCAP::CloudController::Encryptor.db_encryption_key = config.get(:db_encryption_key)
    db = VCAP::CloudController::DB.connect(config.get(:db), db_logger)
    new(db, config.get(:max_migration_duration_in_minutes))
  end

  def initialize(db, max_migration_duration_in_minutes=nil)
    @db = db
    @timeout_in_minutes = default_two_weeks(max_migration_duration_in_minutes)
  end

  def apply_migrations(opts={})
    Sequel.extension :migration
    require 'vcap/sequel_case_insensitive_string_monkeypatch'
    Sequel::Migrator.run(@db, SEQUEL_MIGRATIONS, opts)
  end

  def rollback(number_to_rollback)
    recent_migrations = @db[:schema_migrations].order(Sequel.desc(:filename)).limit(number_to_rollback + 1).all
    recent_migrations = recent_migrations.collect { |hash| hash[:filename].split('_', 2).first.to_i }
    apply_migrations(current: recent_migrations.first, target: recent_migrations.last)
  end

  def wait_for_migrations!
    Sequel.extension :migration
    logger = Steno.logger('cc.db.wait_until_current')

    unless db_is_current_or_newer_than_local_migrations?
      logger.info('waiting indefinitely for database schema to be current')
    end

    timeout_message = 'ccdb.max_migration_duration_in_minutes exceeded'
    Timeout.timeout(@timeout_in_minutes * 60, message: timeout_message) do
      sleep(1) until db_is_current_or_newer_than_local_migrations?
    end

    logger.info('database schema is as new or newer than locally available migrations')
  end

  private

  TWO_WEEKS = 20160
  def default_two_weeks(duration_in_minutes)
    return TWO_WEEKS if duration_in_minutes.nil?

    duration_in_minutes
  end

  def db_is_current_or_newer_than_local_migrations?
    Sequel::Migrator.is_current?(@db, SEQUEL_MIGRATIONS, allow_missing_migration_files: true)
  end
end
