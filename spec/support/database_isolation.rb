module DatabaseIsolation
  def self.choose(isolation, config, db)
    case isolation
    when :truncation
      TruncateTables.new(config, db)
    else
      RollbackTransaction.new
    end
  end

  class TruncateTables
    def initialize(config, db)
      @config = config
      @db = db
    end

    def cleanly
      yield
    ensure
      reset_tables
    end

    def reset_tables
      table_truncator = TableTruncator.new(db)
      table_truncator.truncate_tables

      VCAP::CloudController::Seeds.write_seed_data(config)
    end

    private

    attr_reader :config, :db
  end

  class RollbackTransaction
    def cleanly(&block)
      Sequel::Model.db.transaction(rollback: :always, auto_savepoint: true, &block)
    end
  end
end
