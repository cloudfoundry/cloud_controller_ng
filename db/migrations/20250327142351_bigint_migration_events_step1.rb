require 'database/bigint_migration'

Sequel.migration do
  up do
    if database_type == :postgres && !VCAP::BigintMigration.opt_out?
      if VCAP::BigintMigration.table_empty?(self, :events)
        VCAP::BigintMigration.change_pk_to_bigint(self, :events)
      else
        VCAP::BigintMigration.add_bigint_column(self, :events)
        VCAP::BigintMigration.create_trigger_function(self, :events)
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::BigintMigration.revert_pk_to_integer(self, :events)
      VCAP::BigintMigration.drop_trigger_function(self, :events)
      VCAP::BigintMigration.drop_bigint_column(self, :events)
    end
  end
end
