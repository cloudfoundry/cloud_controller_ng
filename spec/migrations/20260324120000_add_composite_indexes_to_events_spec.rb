require 'migration_spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add composite indexes to events table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260324120000_add_composite_indexes_to_events.rb' }
  end

  describe 'events table' do
    it 'adds composite indexes and handles idempotency gracefully' do
      # Before migration: composite indexes should not exist
      expect(db.indexes(:events)).not_to include(:events_actee_created_at_guid_index)
      expect(db.indexes(:events)).not_to include(:events_space_guid_created_at_guid_index)
      expect(db.indexes(:events)).not_to include(:events_organization_guid_created_at_guid_index)

      # Test up migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      expect(db.indexes(:events)).to include(:events_actee_created_at_guid_index)
      expect(db.indexes(:events)).to include(:events_space_guid_created_at_guid_index)
      expect(db.indexes(:events)).to include(:events_organization_guid_created_at_guid_index)

      # Verify index column order
      expect(db.indexes(:events)[:events_actee_created_at_guid_index][:columns]).to eq(%i[actee created_at guid])
      expect(db.indexes(:events)[:events_space_guid_created_at_guid_index][:columns]).to eq(%i[space_guid created_at guid])
      expect(db.indexes(:events)[:events_organization_guid_created_at_guid_index][:columns]).to eq(%i[organization_guid created_at guid])

      # Test up migration idempotency: running again should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:events)).to include(:events_actee_created_at_guid_index)
      expect(db.indexes(:events)).to include(:events_space_guid_created_at_guid_index)
      expect(db.indexes(:events)).to include(:events_organization_guid_created_at_guid_index)

      # Test down migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:events)).not_to include(:events_actee_created_at_guid_index)
      expect(db.indexes(:events)).not_to include(:events_space_guid_created_at_guid_index)
      expect(db.indexes(:events)).not_to include(:events_organization_guid_created_at_guid_index)

      # Test down migration idempotency: running again should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:events)).not_to include(:events_actee_created_at_guid_index)
      expect(db.indexes(:events)).not_to include(:events_space_guid_created_at_guid_index)
      expect(db.indexes(:events)).not_to include(:events_organization_guid_created_at_guid_index)
    end
  end
end
