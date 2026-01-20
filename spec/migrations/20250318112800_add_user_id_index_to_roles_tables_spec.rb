require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add an index for user_id on all roles tables', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250318112800_add_user_id_index_to_roles_tables.rb' }
  end

  let(:tables) do
    %w[
      organizations_auditors
      organizations_billing_managers
      organizations_managers
      organizations_users
      spaces_auditors
      spaces_developers
      spaces_managers
      spaces_supporters
    ]
  end

  before do
    skip unless db.database_type == :postgres
  end

  describe 'up migration' do
    it 'adds indexes for all tables and handles idempotency' do
      # Verify initial state: no indexes exist
      tables.each do |table|
        table_sym = table.to_sym
        index_sym = :"#{table}_user_id_index"
        expect(db.indexes(table_sym)).not_to include(index_sym)
      end

      # Run migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Verify all indexes were created
      tables.each do |table|
        table_sym = table.to_sym
        index_sym = :"#{table}_user_id_index"
        expect(db.indexes(table_sym)).to include(index_sym)
      end

      # Test idempotency: running migration again should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
    end
  end

  describe 'down migration' do
    it 'removes indexes from all tables and handles idempotency' do
      # Run up migration first
      Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

      # Verify indexes exist
      tables.each do |table|
        table_sym = table.to_sym
        index_sym = :"#{table}_user_id_index"
        expect(db.indexes(table_sym)).to include(index_sym)
      end

      # Run down migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error

      # Verify all indexes were removed
      tables.each do |table|
        table_sym = table.to_sym
        index_sym = :"#{table}_user_id_index"
        expect(db.indexes(table_sym)).not_to include(index_sym)
      end

      # Test idempotency: running rollback again should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
    end
  end
end
