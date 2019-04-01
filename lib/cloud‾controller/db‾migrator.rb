class DBMigrator
  MIGRATIONS_DIR = File.expand_path('../../db', File.dirname(__FILE__))
  SEQUEL_MIGRATIONS = File.join(MIGRATIONS_DIR, 'migrations')

  def self.from_config(config, db_logger)
    VCAP::CloudController::Encryptor.db_encryption_key = config.get(:db_encryption_key)
    db = VCAP::CloudController::DB.connect(config.get(:db), db_logger)
    new(db)
  end

  def initialize(db)
    @db = db
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

  def check_migrations!
    Sequel.extension :migration
    Sequel::Migrator.check_current(@db, SEQUEL_MIGRATIONS)
  end
end
