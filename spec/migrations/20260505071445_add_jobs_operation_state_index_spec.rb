# rubocop:disable Migration/TooManyMigrationRuns
require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

def operation_state_partial_index_present
  # partial indexes are not returned in `db.indexes`. That's why we have to query this information manually.
  partial_indexes = db.fetch("SELECT * FROM pg_indexes WHERE tablename = 'jobs' AND indexname = 'jobs_operation_state_index';")

  index_present = false
  partial_indexes.each do |_index|
    index_present = true
  end

  index_present
end

RSpec.describe 'migration to add operation_state_index on jobs table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260505071445_add_jobs_operation_state_index.rb' }
  end

  describe 'jobs table' do
    it 'adds index and handles idempotency gracefully' do
      if db.database_type == :postgres
        # Test up migration
        expect(operation_state_partial_index_present).to be_falsey
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(operation_state_partial_index_present).to be_truthy

        # Test up migration idempotency
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(operation_state_partial_index_present).to be_truthy

        # Test down migration
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(operation_state_partial_index_present).to be_falsey

        # Test down migration idempotency
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(operation_state_partial_index_present).to be_falsey

      elsif db.database_type == :mysql
        # Test up migration
        expect(db.indexes(:jobs)).not_to include(:jobs_operation_state_index)
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:jobs)).to include(:jobs_operation_state_index)

        # Test up migration idempotency
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:jobs)).to include(:jobs_operation_state_index)

        # Test down migration
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:jobs)).not_to include(:jobs_operation_state_index)

        # Test down migration idempotency
        expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
        expect(db.indexes(:jobs)).not_to include(:jobs_operation_state_index)
      end
    end
  end
end
# rubocop:enable Migration/TooManyMigrationRuns
