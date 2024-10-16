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

      it 'removes the unique constraint' do
        expect(db.indexes(:quota_definitions)).to include(:name)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:name)
      end

      context 'unique constraint on name column does not exist' do
        before do
          db.drop_index :quota_definitions, :name, name: :name
        end

        it 'does not throw an error' do
          expect(db.indexes(:quota_definitions)).not_to include(:name)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(:quota_definitions)).not_to include(:name)
        end
      end
    end

    context 'postgres' do
      before do
        skip if db.database_type != :postgres
      end

      it 'removes the unique constraint' do
        expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
      end

      context 'unique constraint on name column does not exist' do
        before do
          db.alter_table :quota_definitions do
            drop_constraint :quota_definitions_name_key
          end
        end

        it 'does not throw an error' do
          expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
        end
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

      it 'adds the unique constraint' do
        expect(db.indexes(:quota_definitions)).not_to include(:name)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:name)
      end

      context 'unique constraint on name column already exists' do
        before do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

          db.alter_table :quota_definitions do
            add_index :name, name: :name
          end
        end

        it 'does not fail' do
          expect(db.indexes(:quota_definitions)).to include(:name)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(:quota_definitions)).to include(:name)
        end
      end
    end

    context 'postgres' do
      before do
        skip if db.database_type != :postgres
      end

      it 'adds the unique constraint' do
        expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
      end

      context 'unique constraint on name column already exists' do
        before do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

          db.alter_table :quota_definitions do
            add_unique_constraint :name, name: :quota_definitions_name_key
          end
        end

        it 'does not fail' do
          expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
        end
      end
    end
  end
end
