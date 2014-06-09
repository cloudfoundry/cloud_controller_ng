class TableTruncator
  def initialize(db)
    @db = db
  end

  def truncate_tables
    referential_integrity = ReferentialIntegrity.new(db)
    referential_integrity.without do
      case db.database_type
        when :postgres
          db.tables.each do |table|
            db.run("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE;")
          end
        when :mysql
          db.tables.each do |table|
            db.run("TRUNCATE TABLE #{table};")
          end
        when :sqlite
          db.tables.each do |table|
            db.run("DELETE FROM #{table}; DELETE FROM sqlite_sequence WHERE name = '#{table}';")
          end
      end
    end
  end

  private

  attr_reader :db
end
