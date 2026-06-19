require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add or remove unique constraint on name column in quota_definitions table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20241016118000_drop_unique_constraint_quota_definitions_name_key.rb' }
  end

  # Two former examples (one per database type) consolidated into a single
  # it block. The previous structure ran the example for the matching DB
  # and skipped the other, but the skipped example still paid the
  # framework's per-example rollback-and-forward migration cycle. Merging
  # to one example with a DB-specific index name avoids that overhead.
  it 'removes and restores unique constraint with idempotency' do
    index_name = db.database_type == :mysql ? :name : :quota_definitions_name_key

    # Test up migration - removes unique constraint
    expect(db.indexes(:quota_definitions)).to include(index_name)
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
    expect(db.indexes(:quota_definitions)).not_to include(index_name)

    # Test up migration idempotency - constraint already removed
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
    expect(db.indexes(:quota_definitions)).not_to include(index_name)

    # Test down migration - restores unique constraint
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
    expect(db.indexes(:quota_definitions)).to include(index_name)

    # Test down migration idempotency - constraint already exists
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
    expect(db.indexes(:quota_definitions)).to include(index_name)
  end
end
