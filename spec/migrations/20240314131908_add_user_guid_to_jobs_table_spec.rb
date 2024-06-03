require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add user_guid column to jobs table and add an index for that column', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240314131908_add_user_guid_to_jobs_table.rb' }
  end

  describe 'jobs table' do
    it 'adds a column `user_guid`' do
      expect(db[:jobs].columns).not_to include(:user_guid)
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db[:jobs].columns).to include(:user_guid)
    end

    it 'adds an index on the user_guid column' do
      expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)
    end

    describe 'idempotency of up' do
      context '`user_guid` column already exists' do
        before do
          db.add_column :jobs, :user_guid, String, size: 255
        end

        it 'does not fail' do
          expect(db[:jobs].columns).to include(:user_guid)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        end

        it 'continues to create the index' do
          expect(db[:jobs].columns).to include(:user_guid)
          expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)
        end
      end

      context 'index already exists' do
        before do
          db.add_column :jobs, :user_guid, String, size: 255
          db.add_index :jobs, :user_guid, name: :jobs_user_guid_index
        end

        it 'does not fail' do
          expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        end
      end
    end

    describe 'idempotency of down' do
      context 'index does not exist' do
        before do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
          db.drop_index :jobs, :user_guid, name: :jobs_user_guid_index
        end

        it 'does not fail' do
          expect(db[:jobs].columns).to include(:user_guid)
          expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        end

        it 'continues to remove the `user_guid` column' do
          expect(db[:jobs].columns).to include(:user_guid)
          expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(db[:jobs].columns).not_to include(:user_guid)
        end
      end

      context 'index and column do not exist' do
        before do
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
          db.drop_index :jobs, :user_guid, name: :jobs_user_guid_index
          db.drop_column :jobs, :user_guid
        end

        it 'does not fail' do
          expect(db[:jobs].columns).not_to include(:user_guid)
          expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        end
      end
    end
  end
end
