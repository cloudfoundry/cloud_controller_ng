require 'database/bigint_migration'

Sequel.migration do
  up do
    if database_type == :postgres && VCAP::BigintMigration.has_check_constraint?(self, :events)
      VCAP::BigintMigration.drop_check_constraint(self, :events)
      VCAP::BigintMigration.drop_trigger_function(self, :events)
      VCAP::BigintMigration.drop_pk_column(self, :events) # TODO: test
      VCAP::BigintMigration.rename_bigint_column(self, :events) # TODO: test
      VCAP::BigintMigration.add_pk_constraint(self, :events) # TODO: test
      VCAP::BigintMigration.set_pk_as_identity_with_correct_start_value(self, :events) # TODO: test
    end
  end

  down do
    if database_type == :postgres
      if VCAP::BigintMigration.table_empty?(self, :events) # TODO: test
        VCAP::BigintMigration.revert_pk_to_integer(self, :events)
      else
        VCAP::BigintMigration.drop_identity(self, :events) # TODO: test
        VCAP::BigintMigration.drop_pk_constraint(self, :events) # TODO: test
        VCAP::BigintMigration.revert_bigint_column_name(self, :events) # TODO: test
        VCAP::BigintMigration.add_id_column(self, :events) # TODO: test
        VCAP::BigintMigration.backfill_id(self, :events) # TODO: test
        VCAP::BigintMigration.add_pk_constraint(self, :events) # TODO: test
        VCAP::BigintMigration.set_pk_as_identity_with_correct_start_value(self, :events) # TODO: test
        VCAP::BigintMigration.create_trigger_function(self, :events)
        VCAP::BigintMigration.add_check_constraint(self, :events)
      end
    end
  end
end
