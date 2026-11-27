require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add or remove unique constraint on name column in quota_definitions table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20241016118000_drop_unique_constraint_quota_definitions_name_key.rb' }
  end

  let(:index_name) { db.database_type == :mysql ? :name : :quota_definitions_name_key }

  describe 'quota_definitions table' do
    it 'removes and restores unique constraint with idempotency' do
      # Test up migration - removes unique constraint
      expect(db.indexes(:quota_definitions)).to include(index_name)
      expect { run_migration }.not_to raise_error
      expect(db.indexes(:quota_definitions)).not_to include(index_name)

      # Test up migration idempotency - constraint already removed
      test_up_migration_idempotency
      expect(db.indexes(:quota_definitions)).not_to include(index_name)

      # Test down migration - restores unique constraint
      expect { revert_migration }.not_to raise_error
      expect(db.indexes(:quota_definitions)).to include(index_name)

      # Test down migration idempotency - constraint already exists
      test_down_migration_idempotency
      expect(db.indexes(:quota_definitions)).to include(index_name)
    end
  end
end
