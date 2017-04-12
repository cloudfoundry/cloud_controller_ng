class TableTruncator
  def initialize(db, tables=nil)
    @db = db
    @tables = tables || self.class.isolated_tables(db)
  end

  def self.isolated_tables(db)
    db.tables - [:schema_migrations]
  end

  def truncate_tables
    referential_integrity = ReferentialIntegrity.new(db)
    referential_integrity.without do
      case db.database_type
      when :postgres
        tables.each do |table|
          db.run("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE;")
        end
      when :mysql
        tables.each do |table|
          db.run("TRUNCATE TABLE #{table};")
        end
      when :mssql
        tables.each do |table|
          # TODO: could this be changed to TRUNCATE TABLE?
          db.run("DELETE #{table.upcase};")
        end
      end
    end
  end

  private

  attr_reader :db, :tables
end
