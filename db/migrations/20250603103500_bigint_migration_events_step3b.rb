require 'database/bigint_migration'

Sequel.migration do
  up do
    if database_type == :postgres && VCAP::BigintMigration.has_check_constraint?(self, :events)
      VCAP::BigintMigration.drop_check_constraint(self, :events)
      VCAP::BigintMigration.drop_trigger_function(self, :events)
      VCAP::BigintMigration.drop_pk_column(self, :events)
      VCAP::BigintMigration.rename_bigint_column(self, :events)
      VCAP::BigintMigration.add_pk_constraint(self, :events)
      VCAP::BigintMigration.set_pk_as_identity_with_correct_start_value(self, :events)
    end
  end

  down do
    if database_type == :postgres && VCAP::BigintMigration.migration_completed?(self, :events)
      VCAP::BigintMigration.drop_identity(self, :events)
      VCAP::BigintMigration.drop_pk_constraint(self, :events)
      VCAP::BigintMigration.revert_bigint_column_name(self, :events)
      VCAP::BigintMigration.add_id_column(self, :events)
      # TODO: comment
      VCAP::BigintMigration.backfill_id(self, :events)
      VCAP::BigintMigration.add_pk_constraint(self, :events)
      VCAP::BigintMigration.set_pk_as_identity_with_correct_start_value(self, :events)
      VCAP::BigintMigration.create_trigger_function(self, :events)
      VCAP::BigintMigration.add_check_constraint(self, :events)
    end
  end
end
