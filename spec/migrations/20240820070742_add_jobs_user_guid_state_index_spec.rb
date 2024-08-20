require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

def partial_index_present
  # partial indexes are not returned in `db.indexes`. That's why we have to query this information manually.
  partial_indexes = db.fetch("SELECT * FROM pg_indexes WHERE tablename = 'jobs' AND indexname = 'jobs_user_guid_state_index';")

  index_present = false
  partial_indexes.each do |_index|
    index_present = true
  end

  index_present
end

RSpec.describe 'migration to replace user_guid_index with user_guid_state_index on jobs table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240820070742_add_jobs_user_guid_state_index.rb' }
  end

  describe 'jobs table' do
    it 'removes index `jobs_user_guid_index`' do
      skip if db.database_type != :postgres
      expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
    end

    it 'adds an index `jobs_user_guid_state_index`' do
      skip if db.database_type != :postgres
      expect(partial_index_present).to be_falsey
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(partial_index_present).to be_truthy
    end

    describe 'idempotency of up' do
      context '`jobs_user_guid_index` does not exist' do
        before do
          skip if db.database_type != :postgres
          db.drop_index :jobs, :user_guid, name: :jobs_user_guid_index
        end

        it 'continues to create the index' do
          expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
          expect(partial_index_present).to be_falsey
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
          expect(partial_index_present).to be_truthy
          expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
        end
      end

      context '`jobs_user_guid_state_index` already exists' do
        before do
          skip if db.database_type != :postgres
          db.add_index :jobs, %i[user_guid state], name: :jobs_user_guid_state_index, where: "state IN ('PROCESSING', 'POLLING')"
        end

        it 'does not fail' do
          expect(partial_index_present).to be_truthy
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        end
      end
    end

    describe 'idempotency of down' do
      context '`jobs_user_guid_state_index` does not exist' do
        before do
          skip if db.database_type != :postgres
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
          db.drop_index :jobs, %i[user_guid state], name: :jobs_user_guid_state_index
        end

        it 'restores `jobs_user_guid_index`' do
          expect(partial_index_present).to be_falsey
          expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(partial_index_present).to be_falsey
          expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)
        end
      end

      context '`jobs_user_guid_index` already exists' do
        before do
          skip if db.database_type != :postgres
          Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)
          db.add_index :jobs, :user_guid, name: :jobs_user_guid_index
        end

        it 'does not fail' do
          expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)
          expect(partial_index_present).to be_truthy
          expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
          expect(partial_index_present).to be_falsey
          expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)
        end
      end
    end
  end
end
