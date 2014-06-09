module DatabaseIsolation
  def self.choose(isolation)
    case isolation
      when :truncation
        TruncateTables.new
      when :recreation
        RecreateTables.new
      else
        RollbackTransaction.new
    end
  end

  def self.isolated_tables(db)
    db.tables - [:schema_migrations]
  end

  class TruncateTables
    def cleanly
      yield
    ensure
      $spec_env.truncate_and_reseed_all_tables
    end
  end

  class RecreateTables
    def cleanly
      yield
    ensure
      $spec_env.recreate_and_reseed_all_tables
    end
  end

  class RollbackTransaction
    def cleanly
      Sequel::Model.db.transaction(rollback: :always, auto_savepoint: true) do
        yield
      end
    end
  end
end
