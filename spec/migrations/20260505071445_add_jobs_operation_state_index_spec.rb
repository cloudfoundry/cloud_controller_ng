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
      expect { run_migration }.not_to raise_error
      expect(operation_state_index_present?).to be_truthy

      test_up_migration_idempotency
      expect(operation_state_index_present?).to be_truthy

      # Test down migration
      expect { revert_migration }.not_to raise_error
      expect(operation_state_index_present?).to be_falsey

      test_down_migration_idempotency
      expect(operation_state_index_present?).to be_falsey
    end
  end
end
