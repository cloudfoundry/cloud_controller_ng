require 'support/bootstrap/fake_model_tables'

class TableRecreator
  SAFE_VIEWS = [:pg_stat_statements].freeze

  def initialize(db)
    @db = db
  end

  def recreate_tables
    prepare_database

    (db.views - SAFE_VIEWS).each do |view|
      db.drop_view(view)
    end

    disable_referential_integrity

    db.tables.each do |table|
      drop_table_unsafely(table)
    end

    enable_referential_integrity

    DBMigrator.new(db).apply_migrations

    fake_model_tables = FakeModelTables.new(db)
    fake_model_tables.create_tables
  end

  private

  attr_reader :db

  def prepare_database
    if db.database_type == :postgres
      db.execute('CREATE EXTENSION IF NOT EXISTS citext')
    end
  end

  def disable_referential_integrity
    case db.database_type
    when :mysql
      db.execute('SET foreign_key_checks = 0')
    when :postgres
    when :mssql
      # taken from http://dba.stackexchange.com/a/90034
      db.execute(%{
      DECLARE @sql NVARCHAR(MAX);
      SET @sql = N'';
      SELECT @sql = @sql + N' ALTER TABLE ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N' DROP CONSTRAINT ' + QUOTENAME(c.name) + ';'
      FROM sys.objects AS c
      INNER JOIN sys.tables AS t ON c.parent_object_id = t.[object_id]
      INNER JOIN sys.schemas AS s ON t.[schema_id] = s.[schema_id] WHERE c.[type] IN ('D','C','F','PK','UQ')
      ORDER BY c.[type];
      EXEC sys.sp_executesql @sql;
      })
    end
  end

  def enable_referential_integrity
    case db.database_type
    when :mysql
      db.execute('SET foreign_key_checks = 1')
    when :postgres
    when :mssql
    end
  end

  def drop_table_unsafely(table)
    case db.database_type
    when :mysql
      db.drop_table(table)
    when :postgres
      db.drop_table(table, cascade: true)
    when :mssql
      db.drop_table(table)
    end
  end
end
