require 'database/bigint_migration'

Sequel.migration do
  no_transaction

  up do
    if database_type == :postgres && !VCAP::BigintMigration.migration_completed?(self, :events) && !VCAP::BigintMigration.migration_skipped?(self, :events)
      transaction do
        VCAP::BigintMigration.add_check_constraint(self, :events)
      end

      begin
        VCAP::Migration.with_concurrent_timeout(self) do
          VCAP::BigintMigration.validate_check_constraint(self, :events)
        end
      rescue Sequel::CheckConstraintViolation
        raise "Failed to add check constraint on 'events' table!\n" \
              "There are rows where 'id_bigint' does not match 'id', thus step 3 of the bigint migration cannot be executed.\n" \
              "Consider running rake task 'db:bigint_backfill[events]'."
      end
    end
  end

  down do
    transaction do
      VCAP::BigintMigration.drop_check_constraint(self, :events) if database_type == :postgres
    end
  end
end
