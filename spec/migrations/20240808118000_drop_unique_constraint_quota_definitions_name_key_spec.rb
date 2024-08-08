require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add or remove unique constraint on name column in quota_definitions table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240808118000_drop_unique_constraint_quota_definitions_name_key_spec.rb' }
  end
  describe 'up migration' do
    context 'unique constraint on name column exists' do
      it 'removes the unique constraint' do
        if db.database_type == :mysql
          expect(db.indexes(:quota_definitions)).to include(:name)
        elsif db.database_type == :postgres
          expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
        end
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        if db.database_type == :mysql
          expect(db.indexes(:quota_definitions)).not_to include(:name)
        elsif db.database_type == :postgres
          expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
        end
      end

      context 'unique constraint on name column does not exist' do
        it 'does not fail' do
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          if db.database_type == :mysql
            expect(db.indexes(:quota_definitions)).not_to include(:name)
          elsif db.database_type == :postgres
            expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
          end
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          if db.database_type == :mysql
            expect(db.indexes(:quota_definitions)).not_to include(:name)
          elsif db.database_type == :postgres
            expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
          end
        end
      end
    end
  end

  describe 'down migration' do
    context 'unique constraint on name column does not exist' do
      it 'adds the unique constraint' do
        Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
        if db.database_type == :mysql
          expect(db.indexes(:quota_definitions)).not_to include(:name)
        elsif db.database_type == :postgres
          expect(db.indexes(:quota_definitions)).not_to include(:quota_definitions_name_key)
        end
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        if db.database_type == :mysql
          expect(db.indexes(:quota_definitions)).to include(:name)
        elsif db.database_type == :postgres
          expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
        end
      end
    end

    context 'unique constraint on name column does exist' do
      it 'does not fail' do
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        if db.database_type == :mysql
          expect(db.indexes(:quota_definitions)).to include(:name)
        elsif db.database_type == :postgres
          expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
        end
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        if db.database_type == :mysql
          expect(db.indexes(:quota_definitions)).to include(:name)
        elsif db.database_type == :postgres
          expect(db.indexes(:quota_definitions)).to include(:quota_definitions_name_key)
        end
      end
    end
  end
end
