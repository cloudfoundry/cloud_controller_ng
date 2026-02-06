require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add an index for task_guid on app_usage_events table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240529195136_add_task_guid_index_to_app_usage_events.rb' }
  end

  describe 'app_usage_events table' do
    it 'adds and removes index with idempotency' do
      # Test up migration
      expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_task_guid_index)
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:app_usage_events)).to include(:app_usage_events_task_guid_index)

      # Test up migration idempotency: running again when index exists should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:app_usage_events)).to include(:app_usage_events_task_guid_index)

      # Test down migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_task_guid_index)

      # Test down migration idempotency: running rollback again when index doesn't exist should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:app_usage_events)).not_to include(:app_usage_events_task_guid_index)
    end
  end
end
