module DatabaseIsolation
  def self.choose(isolation, config, db)
    case isolation
      when :truncation
        TruncateTables.new(config, db)
      else
        RollbackTransaction.new
    end
  end

  def self.isolated_tables(db)
    db.tables - [:schema_migrations]
  end

  class TruncateTables
    def initialize(config, db)
      @config = config
      @db = db
    end

    def cleanly
      yield
    ensure
      tables = DatabaseIsolation.isolated_tables(db)
      table_truncator = TableTruncator.new(db, tables)
      table_truncator.truncate_tables

      VCAP::CloudController::Seeds.create_seed_quota_definitions(config)
      VCAP::CloudController::Seeds.create_seed_stacks
    end

    private

    attr_reader :config, :db
  end

  class RollbackTransaction
    def cleanly
      Sequel::Model.db.transaction(rollback: :always, auto_savepoint: true) do
        yield
      end
    end
  end
end
