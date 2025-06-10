require 'database/bigint_migration'

Sequel.migration do
  up do
    if database_type == :postgres && !VCAP::BigintMigration.migration_completed?(self, :events) && !VCAP::BigintMigration.migration_skipped?(self, :events)
      transaction do
        VCAP::BigintMigration.drop_check_constraint(self, :events)
        VCAP::BigintMigration.drop_trigger_function(self, :events)
        VCAP::BigintMigration.drop_pk_id_column(self, :events)
        # ...
      end
    end
  end

  down do
    if database_type == :postgres && !VCAP::BigintMigration.migration_completed?(self, :events) && !VCAP::BigintMigration.migration_skipped?(self, :events)
      VCAP::BigintMigration.add_pk_id_column(self, :events)
      VCAP::BigintMigration.create_trigger_function(self, :events)
      VCAP::BigintMigration.backfill_id(self, :events)
      VCAP::BigintMigration.add_check_constraint(self, :events)
      # ...
    end
  end
end
