require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add or remove unique constraint on name column in quota_definitions table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20241016118000_drop_unique_constraint_quota_definitions_name_key_spec.rb' }
  end
  describe 'up migration' do
    context 'mysql' do
      before do
        skip if db.database_type != :mysql
      end

      it 'removes the unique constraint and handles idempotency' do
        expect(db.indexes(:quota_definitions)).to include(:name)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:name)

        # Test idempotency: if constraint already removed, doesn't error
        db.drop_index :quota_definitions, :name, name: :name, if_exists: true
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:name)
      end
    end

    context 'postgres' do
      before do
        skip if db.database_type != :postgres
      end

      it 'removes the unique constraint and handles idempotency' do
        expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)

        # Test idempotency: if constraint already removed, doesn't error
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
      end
    end
  end

  describe 'down migration' do
    before do
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
    end

    context 'mysql' do
      before do
        skip if db.database_type != :mysql
      end

      it 'adds the unique constraint and handles idempotency' do
        expect(db.indexes(:quota_definitions)).not_to include(:name)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:name)

        # Test idempotency: if constraint already exists, doesn't fail
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:name)
      end
    end

    context 'postgres' do
      before do
        skip if db.database_type != :postgres
      end

      it 'adds the unique constraint and handles idempotency' do
        expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)

        # Test idempotency: if constraint already exists, doesn't fail
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
      end
    end
  end
end
