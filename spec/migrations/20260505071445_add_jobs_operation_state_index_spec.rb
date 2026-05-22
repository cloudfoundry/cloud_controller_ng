require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add operation_state_index on jobs table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260505071445_add_jobs_operation_state_index.rb' }
  end

  def operation_state_index_present?
    if db.database_type == :postgres
      db.fetch("SELECT 1 FROM pg_indexes WHERE tablename = 'jobs' AND indexname = 'jobs_operation_state_index'").any?
    else
      db.indexes(:jobs).key?(:jobs_operation_state_index)
    end
  end

  describe 'jobs table' do
    it 'adds index and handles idempotency gracefully' do
      # Test up migration
      expect(operation_state_index_present?).to be_falsey
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(operation_state_index_present?).to be_truthy

      # Test up migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(operation_state_index_present?).to be_truthy

      # Test down migration
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(operation_state_index_present?).to be_falsey

      # Test down migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(operation_state_index_present?).to be_falsey
    end
  end
end
