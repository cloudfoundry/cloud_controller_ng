class Tables
  def initialize(db, tables)
    @db = db
    @tables = tables
  end

  def counts
    @tables.inject({}) do |counts, table|
      counts.merge(table => @db[table].count)
    end
  end
end
