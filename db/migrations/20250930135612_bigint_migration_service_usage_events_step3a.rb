require 'database/bigint_migration_step3ab'

Sequel.migration do
  no_transaction
  VCAP::BigintMigration.step3a_migration(self, :service_usage_events)
end
