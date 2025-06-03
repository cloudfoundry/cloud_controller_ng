module VCAP::BigintMigration
  class << self
    def opt_out?
      opt_out = VCAP::CloudController::Config.config&.get(:skip_bigint_id_migration)
      opt_out.nil? ? false : opt_out
    rescue VCAP::CloudController::Config::InvalidConfigPath
      false
    end

    def table_empty?(db, table)
      db[table].empty?
    end

    def change_pk_to_bigint(db, table)
      db.set_column_type(table, :id, :Bignum) if column_type(db, table, :id) != 'bigint'
    end

    def revert_pk_to_integer(db, table)
      db.set_column_type(table, :id, :integer) if column_type(db, table, :id) == 'bigint'
    end

    def add_bigint_column(db, table)
      db.add_column(table, :id_bigint, :Bignum, if_not_exists: true)
    end

    def drop_bigint_column(db, table)
      db.drop_column(table, :id_bigint, if_exists: true)
    end

    def create_trigger_function(db, table)
      drop_trigger_function(db, table)

      function = <<~FUNC
        BEGIN
          NEW.id_bigint := NEW.id;
          RETURN NEW;
        END;
      FUNC
      db.create_function(function_name(table), function, language: :plpgsql, returns: :trigger)
      db.create_trigger(table, trigger_name(table), function_name(table), each_row: true, events: :insert)
    end

    def drop_trigger_function(db, table)
      db.drop_trigger(table, trigger_name(table), if_exists: true)
      db.drop_function(function_name(table), if_exists: true)
    end

    def backfill(logger, db, table, batch_size: 10_000, iterations: -1)
      raise "table '#{table}' does not contain column 'id_bigint'" unless column_exists?(db, table, :id_bigint)

      logger.info("starting bigint backfill on table '#{table}' (batch_size: #{batch_size}, iterations: #{iterations})")
      loop do
        updated_rows = db.
                       from(table, :batch).
                       with(:batch, db[table].select(:id).where(id_bigint: nil).order(:id).limit(batch_size).for_update.skip_locked).
                       where(Sequel.qualify(table, :id) => :batch__id).
                       update(id_bigint: :batch__id)
        logger.info("updated #{updated_rows} rows")
        iterations -= 1 if iterations > 0
        break if updated_rows < batch_size || iterations == 0
      end
      logger.info("finished bigint backfill on table '#{table}'")
    end

    private

    def column_type(db, table, column)
      db.schema(table).find { |col, _| col == column }&.dig(1, :db_type)
    end

    def function_name(table)
      :"#{table}_set_id_bigint_on_insert"
    end

    def trigger_name(table)
      :"trigger_#{function_name(table)}"
    end

    def column_exists?(db, table, column)
      db[table].columns.include?(column)
    end
  end
end
