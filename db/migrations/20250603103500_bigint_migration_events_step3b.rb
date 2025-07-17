require 'database/bigint_migration'

Sequel.migration do
  no_transaction

  up do
    if database_type == :postgres && VCAP::BigintMigration.has_check_constraint?(self, :events)
      transaction do
        # Drop check constraint and trigger function
        VCAP::BigintMigration.drop_check_constraint(self, :events)
        VCAP::BigintMigration.drop_trigger_function(self, :events)

        # Drop old id column
        VCAP::BigintMigration.drop_pk_column(self, :events)

        # Switch id_bigint -> id
        VCAP::BigintMigration.rename_bigint_column(self, :events)
        VCAP::BigintMigration.add_pk_constraint(self, :events)
        VCAP::BigintMigration.set_pk_as_identity_with_correct_start_value(self, :events)
      end

      # The index is added concurrently.
      VCAP::Migration.with_concurrent_timeout(self) do
        VCAP::BigintMigration.add_timestamp_pk_index(self, :events)
      end
    end
  end

  down do
    if database_type == :postgres && VCAP::BigintMigration.migration_completed?(self, :events)
      transaction do
        # Revert id -> id_bigint
        VCAP::BigintMigration.drop_identity(self, :events)
        VCAP::BigintMigration.drop_timestamp_pk_index(self, :events)
        VCAP::BigintMigration.drop_pk_constraint(self, :events)
        VCAP::BigintMigration.revert_bigint_column_name(self, :events)

        # Restore old id column
        VCAP::BigintMigration.add_id_column(self, :events)

        # To restore the previous state it is necessary to backfill the id column. In case there is a lot of data in the
        # table this might be problematic, e.g. take a longer time.
        #
        # Ideally this down migration SHOULD NEVER BE EXECUTED IN A PRODUCTION SYSTEM! (It's there for proper integration
        # testing of the bigint migration steps.)
        VCAP::BigintMigration.backfill_id(self, :events)

        VCAP::BigintMigration.add_pk_constraint(self, :events)
        VCAP::BigintMigration.set_pk_as_identity_with_correct_start_value(self, :events)

        # Recreate trigger function and check constraint
        VCAP::BigintMigration.create_trigger_function(self, :events)
        VCAP::BigintMigration.add_check_constraint(self, :events)
      end

      # The index is re-added concurrently.
      VCAP::Migration.with_concurrent_timeout(self) do
        VCAP::BigintMigration.add_timestamp_pk_index(self, :events)
      end
    end
  end
end
