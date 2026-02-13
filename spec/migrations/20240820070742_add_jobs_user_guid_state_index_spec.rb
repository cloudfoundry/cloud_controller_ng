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
    it 'replaces indexes and handles idempotency gracefully' do
      skip if db.database_type != :postgres

      # Test basic up migration
      expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)
      expect(partial_index_present).to be_falsey

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
      expect(partial_index_present).to be_truthy

      # Test up migration idempotency: running again when new index exists should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:jobs)).not_to include(:jobs_user_guid_index)
      expect(partial_index_present).to be_truthy

      # Test down migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(partial_index_present).to be_falsey
      expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)

      # Test down migration idempotency: running again when old index exists should not fail
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(partial_index_present).to be_falsey
      expect(db.indexes(:jobs)).to include(:jobs_user_guid_index)
    end
  end
end
