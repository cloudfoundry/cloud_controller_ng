require 'database/bigint_migration'

table = :delayed_jobs

Sequel.migration do
  up do
    if database_type == :postgres && !VCAP::BigintMigration.opt_out?
      if VCAP::BigintMigration.table_empty?(self, table)
        VCAP::BigintMigration.change_pk_to_bigint(self, table)
      else
        VCAP::BigintMigration.add_bigint_column(self, table)
        VCAP::BigintMigration.create_trigger_function(self, table)
      end
    end
  end

  down do
    if database_type == :postgres
      # There is no guarantee that the table is still empty - which was the condition for simply switching the id
      # column's type to bigint. We nevertheless want to revert the type to integer as this is the opposite procedure of
      # the up migration. In case there is a lot of data in the table at this moment in time, this change might be
      # problematic, e.g. take a longer time.
      #
      # Ideally this down migration SHOULD NEVER BE EXECUTED IN A PRODUCTION SYSTEM! (It's there for proper integration
      # testing of the bigint migration steps.)
      VCAP::BigintMigration.revert_pk_to_integer(self, table)

      VCAP::BigintMigration.drop_trigger_function(self, table)
      VCAP::BigintMigration.drop_bigint_column(self, table)
    end
  end
end
