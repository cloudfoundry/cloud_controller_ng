require 'database/bigint_migration'

Sequel.migration do
  up do
    if database_type == :postgres && !VCAP::BigintMigration.migration_completed?(self, :events) && !VCAP::BigintMigration.migration_skipped?(self, :events)
      begin
        VCAP::BigintMigration.add_check_constraint(self, :events)
      rescue Sequel::CheckConstraintViolation
        raise "Failed to add check constraint on 'events' table!\n" \
              "There are rows where 'id_bigint' does not match 'id', thus step 3 of the bigint migration cannot be executed.\n" \
              "Consider running rake task 'db:bigint_backfill[events]'."
      end
    end
  end

  down do
    VCAP::BigintMigration.drop_check_constraint(self, :events) if database_type == :postgres
  end
end
