class TableTruncator
  def initialize(db, tables)
    @db = db
    @tables = tables
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
        when :sqlite
          tables.each do |table|
            db.run("DELETE FROM #{table}; DELETE FROM sqlite_sequence WHERE name = '#{table}';")
          end
      end
    end
  end

  private

  attr_reader :db, :tables
end
