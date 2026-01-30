require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add or remove unique constraint on name column in quota_definitions table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20241016118000_drop_unique_constraint_quota_definitions_name_key.rb' }
  end
  describe 'quota_definitions table' do
    context 'mysql' do
      it 'removes and restores unique constraint with idempotency' do
        skip if db.database_type != :mysql

        # Test up migration - removes unique constraint
        expect(db.indexes(:quota_definitions)).to include(:name)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:name)

        # Test up migration idempotency - constraint already removed
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:name)

        # Test down migration - restores unique constraint
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:name)

        # Test down migration idempotency - constraint already exists
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:name)
      end
    end

    context 'postgres' do
      it 'removes and restores unique constraint with idempotency' do
        skip if db.database_type != :postgres

        # Test up migration - removes unique constraint
        expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)

        # Test up migration idempotency - constraint already removed
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)

        # Test down migration - restores unique constraint
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)

        # Test down migration idempotency - constraint already exists
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
      end
    end
  end
end
