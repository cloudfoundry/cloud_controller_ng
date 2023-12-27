require_relative 'fake_model_tables'

class TableRecreator
  SAFE_VIEWS = [:pg_stat_statements].freeze

  def initialize(db)
    @db = db
  end

  def recreate_tables(without_fake_tables: false, without_migration: false)
    prepare_database

    unless without_migration
      (db.views - SAFE_VIEWS).each do |view|
        db.drop_view(view)
      end

      db.tables.each do |table|
        drop_table_unsafely(table)
      end

      DBMigrator.new(db).apply_migrations
    end

    return if without_fake_tables

    fake_model_tables = FakeModelTables.new(db)
    fake_model_tables.create_tables
  end

  private

  attr_reader :db

  def prepare_database
    return unless db.database_type == :postgres

    db.execute('CREATE EXTENSION IF NOT EXISTS citext')
  end

  def drop_table_unsafely(table)
    case db.database_type
    when :mysql
      db.execute('SET foreign_key_checks = 0')
      db.drop_table(table)
      db.execute('SET foreign_key_checks = 1')

    when :postgres
      db.drop_table(table, cascade: true)
    end
  end
end
