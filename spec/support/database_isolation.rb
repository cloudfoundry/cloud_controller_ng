module DatabaseIsolation
  def self.choose(isolation, db)
    case isolation
    when :truncation
      TruncateTables.new(db)
    else
      RollbackTransaction.new
    end
  end

  class TruncateTables
    def initialize(db)
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

      # VCAP::CloudController::Seeds requires the :api config
      TestConfig.context = :api
      TestConfig.reset
      VCAP::CloudController::Seeds.write_seed_data(TestConfig.config_instance)
    end

    private

    attr_reader :config, :db
  end

  class RollbackTransaction
    def cleanly(&)
      Sequel::Model.db.transaction(rollback: :always, auto_savepoint: true, &)
    end
  end
end
