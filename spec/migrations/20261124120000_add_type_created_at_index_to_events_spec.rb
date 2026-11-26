require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add type/created_at composite index to events table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20261124120000_add_type_created_at_index_to_events.rb' }
  end

  describe 'events table' do
    it 'adds the composite index and handles idempotency gracefully' do
      # Before migration: composite index should not exist
      expect(db.indexes(:events)).not_to include(:events_type_created_at_id_index)

      # Test up migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      expect(db.indexes(:events)).to include(:events_type_created_at_id_index)

      # Verify index column order
      expect(db.indexes(:events)[:events_type_created_at_id_index][:columns]).to eq(%i[type created_at id])

      # Test up migration idempotency: running again should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:events)).to include(:events_type_created_at_id_index)

      # Test down migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:events)).not_to include(:events_type_created_at_id_index)

      # Test down migration idempotency: running again should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:events)).not_to include(:events_type_created_at_id_index)
    end
  end
end
