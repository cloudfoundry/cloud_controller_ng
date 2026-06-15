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
  # Schema-qualified writes (e.g. INSERT INTO public.users) trigger a full truncate as a safe fallback.
  class WrittenTablesLogger
    WRITE_REGEX = /\b(?:INSERT INTO|UPDATE|DELETE FROM|TRUNCATE TABLE|TRUNCATE)\s+(\S+)/i

    attr_reader :tables

    def initialize
      @tables = Set.new
      @full_reset = false
    end

    def full_reset?
      @full_reset
    end

    def capture(msg)
      return unless msg =~ WRITE_REGEX

      target = ::Regexp.last_match(1).delete('`"')
      if target.include?('.')
        @full_reset = true
      else
        @tables << target.to_sym
      end
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
        tables = logger.full_reset? ? TableTruncator.isolated_tables(db) : logger.tables.to_a & TableTruncator.isolated_tables(db)
        reset_tables(tables)
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
