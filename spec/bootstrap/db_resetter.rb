require "bootstrap/fake_model_tables"

class DbResetter
  def initialize(db)
    @db = db
  end

  def reset
    prepare_database

    db.tables.each do |table|
      drop_table_unsafely(table)
    end

    DBMigrator.new(db).apply_migrations

    fake_model_tables = FakeModelTables.new(db)
    fake_model_tables.create_tables
  end

  private

  attr_reader :db

  def prepare_database
    if db.database_type == :postgres
      db.execute("CREATE EXTENSION IF NOT EXISTS citext")
    end
  end

  def drop_table_unsafely(table)
    case db.database_type
      when :sqlite
        db.execute("PRAGMA foreign_keys = OFF")
        db.drop_table(table)
        db.execute("PRAGMA foreign_keys = ON")

      when :mysql
        db.execute("SET foreign_key_checks = 0")
        db.drop_table(table)
        db.execute("SET foreign_key_checks = 1")

      # Postgres uses CASCADE directive in DROP TABLE
      # to remove foreign key contstraints.
      # http://www.postgresql.org/docs/9.2/static/sql-droptable.html
      else
        db.drop_table(table, :cascade => true)
    end
  end
end
