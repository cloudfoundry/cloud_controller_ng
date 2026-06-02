module DatabaseIsolation
  def self.choose(isolation, db)
    case isolation
    when :truncation
      TruncateTables.new(db)
    else
      RollbackTransaction.new
    end
  end

  # Sequel logger that records which tables an example wrote to, so we can truncate only those.
  class WrittenTablesLogger
    WRITE_REGEX = /\b(?:INSERT INTO|UPDATE|DELETE FROM|TRUNCATE TABLE|TRUNCATE)\s+[`"]?(\w+)/i

    attr_reader :tables

    def initialize
      @tables = Set.new
    end

    def capture(msg)
      @tables << ::Regexp.last_match(1).to_sym if msg =~ WRITE_REGEX
    end

    alias_method :info,  :capture
    alias_method :warn,  :capture
    alias_method :debug, :capture
    alias_method :error, :capture
    alias_method :fatal, :capture
  end

  class TruncateTables
    def initialize(db)
      @db = db
    end

    def cleanly
      logger = WrittenTablesLogger.new
      db.loggers << logger
      begin
        yield
      ensure
        db.loggers.delete(logger)
        reset_tables(logger.tables.to_a & TableTruncator.isolated_tables(db))
      end
    end

    def reset_tables(tables)
      return if tables.empty?

      TableTruncator.new(db, tables).truncate_tables

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
