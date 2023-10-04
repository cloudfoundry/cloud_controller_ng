class ReferentialIntegrity
  def initialize(db)
    @db = db
  end

  def without(&)
    case db.database_type
    when :postgres
      without_referential_integrity_postgres(&)
    when :mysql
      without_referential_integrity_mysql(&)
    end
  end

  private

  attr_reader :db

  def without_referential_integrity_postgres
    db.run(db.tables.map { |name| "ALTER TABLE #{name} DISABLE TRIGGER ALL" }.join(';'))

    yield
  ensure
    db.run(db.tables.map { |name| "ALTER TABLE #{name} ENABLE TRIGGER ALL" }.join(';'))
  end

  def without_referential_integrity_mysql
    db.disconnect
    db.run('SET FOREIGN_KEY_CHECKS = 0;')
    yield
  ensure
    db.run('SET FOREIGN_KEY_CHECKS = 1;')
  end
end
