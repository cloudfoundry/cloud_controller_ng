require 'database/bigint_migration'

module VCAP::BigintMigration
  class << self
    def step3a_migration(migration, table)
      migration.up do
        if database_type == :postgres &&
           !VCAP::BigintMigration.migration_completed?(self, table) &&
           !VCAP::BigintMigration.migration_skipped?(self, table)
          transaction { VCAP::BigintMigration.add_check_constraint(self, table) }
          begin
            VCAP::Migration.with_concurrent_timeout(self) do
              VCAP::BigintMigration.validate_check_constraint(self, table)
            end
          rescue Sequel::CheckConstraintViolation
            raise "Failed to add check constraint on '#{table}' table!\n" \
                  "There are rows where 'id_bigint' does not match 'id', " \
                  "thus step 3 of the bigint migration cannot be executed.\n" \
                  "Consider running rake task 'db:bigint_backfill[#{table}]'."
          end
        end
      end

      migration.down do
        transaction { VCAP::BigintMigration.drop_check_constraint(self, table) if database_type == :postgres }
      end
    end

    def step3b_migration(migration, table)
      migration.up do
        if database_type == :postgres && VCAP::BigintMigration.has_check_constraint?(self, table)
          transaction do
            # Drop check constraint and trigger function
            VCAP::BigintMigration.drop_check_constraint(self, table)
            VCAP::BigintMigration.drop_trigger_function(self, table)

            # Drop old id column
            VCAP::BigintMigration.drop_pk_column(self, table)

            # Switch id_bigint -> id
            VCAP::BigintMigration.rename_bigint_column(self, table)
            VCAP::BigintMigration.add_pk_constraint(self, table)
            VCAP::BigintMigration.set_pk_as_identity_with_correct_start_value(self, table)
          end
        end
      end

      migration.down do
        if database_type == :postgres && VCAP::BigintMigration.migration_completed?(self, table)
          transaction do
            # Revert id -> id_bigint
            VCAP::BigintMigration.drop_identity(self, table)
            VCAP::BigintMigration.drop_timestamp_pk_index(self, table)
            VCAP::BigintMigration.drop_pk_constraint(self, table)
            VCAP::BigintMigration.revert_bigint_column_name(self, table)

            # Restore old id column
            VCAP::BigintMigration.add_id_column(self, table)

            # To restore the previous state it is necessary to backfill the id column. In case there is a lot of data in the
            # table this might be problematic, e.g. take a longer time.
            #
            # Ideally this down migration SHOULD NEVER BE EXECUTED IN A PRODUCTION SYSTEM! (It's there for proper integration
            # testing of the bigint migration steps.)
            VCAP::BigintMigration.backfill_id(self, table)

            VCAP::BigintMigration.add_pk_constraint(self, table)
            VCAP::BigintMigration.set_pk_as_identity_with_correct_start_value(self, table)

            # Recreate trigger function and check constraint
            VCAP::BigintMigration.create_trigger_function(self, table)
            VCAP::BigintMigration.add_check_constraint(self, table)
          end
        end
      end
    end
  end
end
